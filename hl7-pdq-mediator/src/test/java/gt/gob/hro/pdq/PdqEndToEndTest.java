package gt.gob.hro.pdq;

import ca.uhn.hl7v2.DefaultHapiContext;
import ca.uhn.hl7v2.HapiContext;
import ca.uhn.hl7v2.app.Connection;
import ca.uhn.hl7v2.app.HL7Service;
import ca.uhn.hl7v2.model.Message;
import ca.uhn.hl7v2.parser.CanonicalModelClassFactory;
import ca.uhn.hl7v2.util.Terser;
import ca.uhn.hl7v2.validation.impl.ValidationContextFactory;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Prueba de extremo a extremo: cliente MLLP (HAPI) -> mediador -> facade FHIR simulado.
 */
class PdqEndToEndTest {

    private static HttpServer fhir;
    private static HL7Service mediator;
    private static Connection conn;
    private static HapiContext clientCtx;
    private static final ObjectMapper mapper = new ObjectMapper();

    @BeforeAll
    static void setUp() throws Exception {
        JsonNode patient;
        try (InputStream in = PdqEndToEndTest.class.getResourceAsStream("/patient-837871.json")) {
            patient = mapper.readTree(in);
        }

        // Facade FHIR simulado
        fhir = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        fhir.createContext("/fhir/Patient", ex -> {
            String query = ex.getRequestURI().getRawQuery();
            String token = "";
            for (String kv : query.split("&")) {
                if (kv.startsWith("identifier=")) token = URLDecoder.decode(kv.substring(11), StandardCharsets.UTF_8);
            }
            if (token.endsWith("|500")) {
                ex.sendResponseHeaders(500, -1);
                ex.close();
                return;
            }
            String system = token.substring(0, token.indexOf('|'));
            String value = token.substring(token.indexOf('|') + 1);
            boolean match = false;
            for (JsonNode id : patient.path("identifier")) {
                if (id.path("system").asText().equals(system) && id.path("value").asText().equals(value)) match = true;
            }
            String body = "{\"resourceType\":\"Bundle\",\"type\":\"searchset\",\"total\":" + (match ? 1 : 0)
                    + ",\"entry\":[" + (match ? "{\"resource\":" + patient + "}" : "") + "]}";
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
            ex.getResponseHeaders().add("Content-Type", "application/fhir+json; charset=utf-8");
            ex.sendResponseHeaders(200, bytes.length);
            try (OutputStream os = ex.getResponseBody()) {
                os.write(bytes);
            }
        });
        fhir.start();

        int mllpPort;
        try (ServerSocket s = new ServerSocket(0)) {
            mllpPort = s.getLocalPort();
        }
        Map<String, String> env = new HashMap<>();
        env.put("FHIR_BASE_URL", "http://127.0.0.1:" + fhir.getAddress().getPort() + "/fhir");
        env.put("MLLP_PORT", String.valueOf(mllpPort));
        mediator = App.start(new Config(env));

        clientCtx = new DefaultHapiContext();
        clientCtx.setModelClassFactory(new CanonicalModelClassFactory("2.5"));
        clientCtx.setValidationContext(ValidationContextFactory.noValidation());
        conn = clientCtx.newClient("127.0.0.1", mllpPort, false);
    }

    @AfterAll
    static void tearDown() throws Exception {
        if (conn != null) conn.close();
        if (mediator != null) mediator.stopAndWait();
        if (fhir != null) fhir.stop(0);
        if (clientCtx != null) clientCtx.close();
    }

    private static Terser send(String... segments) throws Exception {
        Message req = clientCtx.getPipeParser().parse(String.join("\r", segments));
        Message resp = conn.getInitiator().sendAndReceive(req);
        System.out.println(resp.encode().replace("\r", "\n") + "\n");
        return new Terser(resp);
    }

    private static String msh(String type, String control, String version) {
        return "MSH|^~\\&|SIS_EXT|HOSPX|HRO_PDQ|HRO|20261026103000||" + type + "|" + control + "|P|" + version;
    }

    @Test
    void buscaPorHistoriaClinica() throws Exception {
        Terser t = send(msh("QBP^Q22^QBP_Q21", "Q0001", "2.5"),
                "QPD|IHE PDQ Query|Q0001|@PID.3.1^837871~@PID.3.5^MR",
                "RCP|I|10^RD");
        assertEquals("RSP", t.get("/MSH-9-1"));
        assertEquals("K22", t.get("/MSH-9-2"));
        assertEquals("SIS_EXT", t.get("/MSH-5"));
        assertEquals("AA", t.get("/MSA-1"));
        assertEquals("Q0001", t.get("/MSA-2"));
        assertEquals("Q0001", t.get("/QAK-1"));
        assertEquals("OK", t.get("/QAK-2"));
        assertEquals("1", t.get("/QAK-4"));
        assertEquals("837871", t.get("/QUERY_RESPONSE/PID-3(0)-1"));
        assertEquals("HRO", t.get("/QUERY_RESPONSE/PID-3(0)-4-1"));
        assertEquals("MR", t.get("/QUERY_RESPONSE/PID-3(0)-5"));
        assertEquals("3593745140801", t.get("/QUERY_RESPONSE/PID-3(1)-1"));
        assertEquals("NI", t.get("/QUERY_RESPONSE/PID-3(1)-5"));
        assertEquals("AJUCUM CUA", t.get("/QUERY_RESPONSE/PID-5-1"));
        assertEquals("ADOLFO", t.get("/QUERY_RESPONSE/PID-5-2"));
        assertEquals("MARTIN", t.get("/QUERY_RESPONSE/PID-5-3"));
        assertEquals("JUANA OLIVIA CUA CASTRO", t.get("/QUERY_RESPONSE/PID-6-1"));
        assertEquals("19970528", t.get("/QUERY_RESPONSE/PID-7"));
        assertEquals("M", t.get("/QUERY_RESPONSE/PID-8"));
        assertEquals("Totonicapán", t.get("/QUERY_RESPONSE/PID-11-3"));
        assertEquals("TOTONICAPAN", t.get("/QUERY_RESPONSE/PID-11-4"));
    }

    @Test
    void buscaPorDpiConEspacios() throws Exception {
        Terser t = send(msh("QBP^Q22^QBP_Q21", "Q0002", "2.5"),
                "QPD|IHE PDQ Query|Q0002|@PID.3.1^3593 74514 0801~@PID.3.5^NI",
                "RCP|I|10^RD");
        assertEquals("AA", t.get("/MSA-1"));
        assertEquals("OK", t.get("/QAK-2"));
        assertEquals("837871", t.get("/QUERY_RESPONSE/PID-3(0)-1"));
    }

    @Test
    void noEncontrado() throws Exception {
        Terser t = send(msh("QBP^Q22^QBP_Q21", "Q0003", "2.5"),
                "QPD|IHE PDQ Query|Q0003|@PID.3.1^999999~@PID.3.5^MR",
                "RCP|I|10^RD");
        assertEquals("AA", t.get("/MSA-1"));
        assertEquals("NF", t.get("/QAK-2"));
        assertEquals("0", t.get("/QAK-4"));
        assertTrue(t.get("/QUERY_RESPONSE/PID-3(0)-1") == null);
    }

    @Test
    void formaCompactaSinTipoEnV23() throws Exception {
        Terser t = send(msh("QBP^Q22^QBP_Q21", "Q0004", "2.3"),
                "QPD|Q22^Find Candidates^HL7|Q0004|@PID.3^3593745140801",
                "RCP|I");
        assertEquals("2.3", t.get("/MSH-12"));
        assertEquals("OK", t.get("/QAK-2"));
        assertEquals("837871", t.get("/QUERY_RESPONSE/PID-3(0)-1"));
    }

    @Test
    void tipoDeIdentificadorInvalido() throws Exception {
        Terser t = send(msh("QBP^Q22^QBP_Q21", "Q0005", "2.5"),
                "QPD|IHE PDQ Query|Q0005|@PID.3.1^837871~@PID.3.5^XX",
                "RCP|I|10^RD");
        assertEquals("AE", t.get("/MSA-1"));
        assertEquals("AE", t.get("/QAK-2"));
        assertEquals("103", t.get("/ERR-3-1"));
        assertEquals("QPD", t.get("/ERR-2-1"));
    }

    @Test
    void facadeCaido() throws Exception {
        Terser t = send(msh("QBP^Q22^QBP_Q21", "Q0006", "2.5"),
                "QPD|IHE PDQ Query|Q0006|@PID.3.1^500~@PID.3.5^MR",
                "RCP|I|10^RD");
        assertEquals("AE", t.get("/MSA-1"));
        assertEquals("207", t.get("/ERR-3-1"));
    }

    @Test
    void mensajeNoSoportado() throws Exception {
        Terser t = send(msh("ADT^A04^ADT_A01", "A0001", "2.5"),
                "EVN|A04|20261026103000",
                "PID|1||837871^^^HRO^MR");
        assertEquals("ACK", t.get("/MSH-9-1"));
        assertEquals("AR", t.get("/MSA-1"));
        assertEquals("A0001", t.get("/MSA-2"));
    }
}
