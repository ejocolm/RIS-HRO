package gt.gob.hro.pdq;

import ca.uhn.hl7v2.AcknowledgmentCode;
import ca.uhn.hl7v2.ErrorCode;
import ca.uhn.hl7v2.HL7Exception;
import ca.uhn.hl7v2.HapiContext;
import ca.uhn.hl7v2.model.Message;
import ca.uhn.hl7v2.model.v25.datatype.ERL;
import ca.uhn.hl7v2.model.v25.message.QBP_Q21;
import ca.uhn.hl7v2.model.v25.message.RSP_K21;
import ca.uhn.hl7v2.model.v25.segment.ERR;
import ca.uhn.hl7v2.model.v25.segment.MSH;
import ca.uhn.hl7v2.protocol.ReceivingApplication;
import ca.uhn.hl7v2.util.Terser;
import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;

/**
 * IHE PDQ (ITI-21): recibe QBP^Q22, busca en el facade FHIR y responde RSP^K22.
 *
 * Parámetros soportados en QPD-3:
 *   @PID.3.1^valor            identificador
 *   @PID.3.5^MR | NI | NNGTM  tipo (MR = historia clínica, NI/NNGTM/DPI = DPI)
 *   @PID.3.4.1^HRO | RENAP    autoridad (alternativa al tipo)
 *   @PID.3^valor^^^AUT^TIPO   forma compacta en un solo parámetro
 * Si no viene tipo ni autoridad se busca en ambos sistemas.
 */
public final class PdqApplication implements ReceivingApplication<Message> {

    private static final Logger log = LoggerFactory.getLogger(PdqApplication.class);

    private final Config cfg;
    private final FhirClient fhir;
    private final PidMapper pidMapper;
    private final HapiContext ctx;

    public PdqApplication(Config cfg, FhirClient fhir, HapiContext ctx) {
        this.cfg = cfg;
        this.fhir = fhir;
        this.ctx = ctx;
        this.pidMapper = new PidMapper(cfg.systemToAuthority);
    }

    @Override
    public boolean canProcess(Message message) {
        return true;
    }

    @Override
    public Message processMessage(Message message, Map<String, Object> metadata) throws HL7Exception {
        Terser t = new Terser(message);
        String type = t.get("/MSH-9-1") + "^" + t.get("/MSH-9-2");
        log.info("Recibido {} control={} desde {}", type, t.get("/MSH-10"), metadata.get("SENDING_IP"));

        try {
            if (!(message instanceof QBP_Q21 qbp) || !"Q22".equals(t.get("/MSH-9-2"))) {
                return message.generateACK(AcknowledgmentCode.AR,
                        new HL7Exception("Unsupported message type " + type, ErrorCode.UNSUPPORTED_MESSAGE_TYPE));
            }
            return handleQuery(qbp);
        } catch (IOException e) {
            throw new HL7Exception(e);
        }
    }

    // ------------------------------------------------------------------------

    private RSP_K21 handleQuery(QBP_Q21 qbp) throws HL7Exception, IOException {
        QpdParams q = QpdParams.from(qbp.getQPD());

        if (q.value.isEmpty()) {
            return error(qbp, ErrorCode.REQUIRED_FIELD_MISSING, "Required field missing: @PID.3.1", "QPD^1^3");
        }

        // ¿En qué system(s) buscar?
        List<String> systems = new ArrayList<>();
        if (!q.typeOrAuthority.isEmpty()) {
            String sys = cfg.typeToSystem.get(q.typeOrAuthority);
            if (sys == null) {
                return error(qbp, ErrorCode.TABLE_VALUE_NOT_FOUND,
                        "Identifier type not supported: " + q.typeOrAuthority, "QPD^1^3");
            }
            systems.add(sys);
        } else {
            systems.addAll(new LinkedHashSet<>(cfg.typeToSystem.values()));
        }

        int limit = cfg.defaultLimit;
        String rcp2 = qbp.getRCP().getQuantityLimitedRequest().getQuantity().getValue();
        if (rcp2 != null && rcp2.matches("\\d+")) limit = Math.max(1, Integer.parseInt(rcp2));

        // Buscar en el facade
        Map<String, JsonNode> found = new LinkedHashMap<>();
        try {
            for (String sys : systems) {
                for (JsonNode p : fhir.searchByIdentifier(sys, q.value, limit)) {
                    found.putIfAbsent(p.path("id").asText(String.valueOf(found.size())), p);
                }
            }
        } catch (Exception e) {
            log.error("Error consultando el facade FHIR", e);
            return error(qbp, ErrorCode.APPLICATION_INTERNAL_ERROR,
                    "Application internal error: patient source unavailable", null);
        }

        List<JsonNode> patients = new ArrayList<>(found.values());
        if (patients.size() > limit) patients = patients.subList(0, limit);
        log.info("Consulta {} value={} systems={} -> {} resultado(s)",
                qbp.getQPD().getQueryTag().getValue(), q.value, systems, patients.size());

        RSP_K21 rsp = newResponse(qbp, AcknowledgmentCode.AA);
        rsp.getQAK().getQueryResponseStatus().setValue(patients.isEmpty() ? "NF" : "OK");
        rsp.getQAK().getHitCount().setValue(String.valueOf(patients.size()));
        rsp.getQAK().getThisPayload().setValue(String.valueOf(patients.size()));
        rsp.getQAK().getHitsRemaining().setValue("0");

        int setId = 1;
        for (JsonNode p : patients) {
            pidMapper.fill(rsp.getQUERY_RESPONSE(setId - 1).getPID(), setId, p);
            setId++;
        }
        return rsp;
    }

    private RSP_K21 error(QBP_Q21 qbp, ErrorCode code, String text, String location)
            throws HL7Exception, IOException {
        RSP_K21 rsp = newResponse(qbp, AcknowledgmentCode.AE);
        ERR err = rsp.getERR();
        if (location != null) {
            ERL erl = err.getErrorLocation(0);
            erl.parse(location);
        }
        err.getHL7ErrorCode().getIdentifier().setValue(String.valueOf(code.getCode()));
        err.getHL7ErrorCode().getText().setValue(text);
        err.getHL7ErrorCode().getNameOfCodingSystem().setValue("HL70357");
        err.getSeverity().setValue("E");
        rsp.getQAK().getQueryResponseStatus().setValue("AE");
        return rsp;
    }

    /** RSP^K22 con MSH, MSA, QAK (tag y nombre) y eco del QPD. */
    private RSP_K21 newResponse(QBP_Q21 qbp, AcknowledgmentCode ack) throws HL7Exception, IOException {
        RSP_K21 rsp = new RSP_K21(ctx.getModelClassFactory());
        rsp.setParser(ctx.getPipeParser());
        rsp.initQuickstart("RSP", "K22", "P");

        MSH in = qbp.getMSH();
        MSH out = rsp.getMSH();
        out.getMessageType().getMessageStructure().setValue("RSP_K21");
        out.getSendingApplication().getNamespaceID().setValue(cfg.sendingApp);
        out.getSendingFacility().getNamespaceID().setValue(cfg.sendingFacility);
        out.getReceivingApplication().parse(in.getSendingApplication().encode());
        out.getReceivingFacility().parse(in.getSendingFacility().encode());
        String processing = in.getProcessingID().getProcessingID().getValue();
        out.getProcessingID().getProcessingID().setValue(processing == null ? "P" : processing);
        String version = in.getVersionID().getVersionID().getValue();
        if (version != null && !version.isEmpty()) out.getVersionID().getVersionID().setValue(version);
        out.getCharacterSet(0).setValue(cfg.hl7CharsetName);

        rsp.getMSA().getAcknowledgmentCode().setValue(ack.name());
        rsp.getMSA().getMessageControlID().setValue(in.getMessageControlID().getValue());

        rsp.getQAK().getQueryTag().setValue(qbp.getQPD().getQueryTag().getValue());
        rsp.getQAK().getMessageQueryName().parse(qbp.getQPD().getMessageQueryName().encode());
        rsp.getQPD().parse(qbp.getQPD().encode());
        return rsp;
    }
}
