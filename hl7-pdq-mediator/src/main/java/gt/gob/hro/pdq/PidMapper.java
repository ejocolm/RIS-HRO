package gt.gob.hro.pdq;

import ca.uhn.hl7v2.HL7Exception;
import ca.uhn.hl7v2.model.DataTypeException;
import ca.uhn.hl7v2.model.v25.datatype.CX;
import ca.uhn.hl7v2.model.v25.datatype.XAD;
import ca.uhn.hl7v2.model.v25.datatype.XPN;
import ca.uhn.hl7v2.model.v25.datatype.XTN;
import ca.uhn.hl7v2.model.v25.segment.PID;
import com.fasterxml.jackson.databind.JsonNode;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * FHIR Patient (JSON) -> segmento PID v2.5.
 * HAPI se encarga de escapar los delimitadores al codificar.
 */
public final class PidMapper {

    private static final String EXT_MADRE = "http://hro.gob.gt/fhir/StructureDefinition/nombre-madre";

    private final Map<String, String> systemToAuthority;

    public PidMapper(Map<String, String> systemToAuthority) {
        this.systemToAuthority = systemToAuthority;
    }

    public void fill(PID pid, int setId, JsonNode p) throws HL7Exception {
        pid.getSetIDPID().setValue(String.valueOf(setId));

        // PID-3: identificadores  valor^^^Autoridad^Tipo
        int rep = 0;
        for (JsonNode id : p.path("identifier")) {
            String value = id.path("value").asText("");
            if (value.isEmpty()) continue;
            CX cx = pid.getPatientIdentifierList(rep++);
            cx.getIDNumber().setValue(value);
            String authority = systemToAuthority.get(id.path("system").asText(""));
            if (authority != null) cx.getAssigningAuthority().getNamespaceID().setValue(authority);
            String type = id.path("type").path("coding").path(0).path("code").asText("");
            if (!type.isEmpty()) cx.getIdentifierTypeCode().setValue(type);
        }

        // PID-5: Apellidos^PrimerNombre^OtrosNombres
        JsonNode name = pickName(p.path("name"));
        if (!name.isMissingNode()) {
            XPN xpn = pid.getPatientName(0);
            set(xpn.getFamilyName().getSurname(), name.path("family").asText(""));
            List<String> given = new ArrayList<>();
            name.path("given").forEach(g -> given.add(g.asText()));
            if (!given.isEmpty()) xpn.getGivenName().setValue(given.get(0));
            if (given.size() > 1) {
                xpn.getSecondAndFurtherGivenNamesOrInitialsThereof()
                        .setValue(String.join(" ", given.subList(1, given.size())));
            }
        }

        // PID-6: nombre de la madre (extensión propia, texto completo)
        String madre = extension(p, EXT_MADRE);
        if (!madre.isEmpty()) pid.getMotherSMaidenName(0).getFamilyName().getSurname().setValue(madre);

        // PID-7: AAAAMMDD
        String birth = p.path("birthDate").asText("").replace("-", "");
        if (!birth.isEmpty()) pid.getDateTimeOfBirth().getTime().setValue(birth);

        // PID-8
        String sex = switch (p.path("gender").asText("")) {
            case "male" -> "M";
            case "female" -> "F";
            case "other" -> "O";
            case "unknown" -> "U";
            default -> "";
        };
        set(pid.getAdministrativeSex(), sex);

        // PID-11: Calle^Otra^Ciudad^Depto^CP^País
        int addrRep = 0;
        for (JsonNode a : p.path("address")) {
            XAD xad = pid.getPatientAddress(addrRep++);
            List<String> lines = new ArrayList<>();
            a.path("line").forEach(l -> lines.add(l.asText()));
            if (!lines.isEmpty()) xad.getStreetAddress().getStreetOrMailingAddress().setValue(lines.get(0));
            if (lines.size() > 1) xad.getOtherDesignation().setValue(String.join(" ", lines.subList(1, lines.size())));
            set(xad.getCity(), a.path("city").asText(""));
            set(xad.getStateOrProvince(), a.path("state").asText(a.path("district").asText("")));
            set(xad.getZipOrPostalCode(), a.path("postalCode").asText(""));
            set(xad.getCountry(), a.path("country").asText(""));
        }

        // PID-13: teléfonos del paciente (no los de contact[])
        int telRep = 0;
        for (JsonNode t : p.path("telecom")) {
            if (!"phone".equals(t.path("system").asText())) continue;
            XTN xtn = pid.getPhoneNumberHome(telRep++);
            xtn.getTelecommunicationUseCode().setValue("PRN");
            xtn.getTelecommunicationEquipmentType().setValue("PH");
            xtn.getUnformattedTelephoneNumber().setValue(t.path("value").asText());
        }

        // PID-29 / PID-30: fallecimiento
        if (p.hasNonNull("deceasedDateTime")) {
            String dt = p.path("deceasedDateTime").asText().replaceAll("[^0-9]", "");
            if (dt.length() > 14) dt = dt.substring(0, 14);
            pid.getPatientDeathDateAndTime().getTime().setValue(dt);
            pid.getPatientDeathIndicator().setValue("Y");
        } else if (p.has("deceasedBoolean")) {
            pid.getPatientDeathIndicator().setValue(p.path("deceasedBoolean").asBoolean() ? "Y" : "N");
        }
    }

    private static void set(ca.uhn.hl7v2.model.Primitive field, String value) throws DataTypeException {
        if (value != null && !value.isEmpty()) field.setValue(value);
    }

    private static JsonNode pickName(JsonNode names) {
        for (JsonNode n : names) {
            if ("official".equals(n.path("use").asText())) return n;
        }
        return names.path(0);
    }

    private static String extension(JsonNode p, String url) {
        for (JsonNode e : p.path("extension")) {
            if (url.equals(e.path("url").asText())) return e.path("valueString").asText("");
        }
        return "";
    }
}
