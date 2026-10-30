package gt.gob.hro.pdq;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Configuración por variables de entorno.
 */
public final class Config {

    /** URL base del facade FHIR (sin "/" final). */
    public final String fhirBaseUrl;
    /** Valor completo del header Authorization para el facade/OpenHIM (opcional). */
    public final String fhirAuthHeader;
    /** Puerto MLLP en el que escucha el mediador. */
    public final int mllpPort;
    /** Timeout de las llamadas al facade, en segundos. */
    public final int fhirTimeoutSeconds;
    /** Máximo de pacientes a devolver si la consulta no trae RCP-2. */
    public final int defaultLimit;
    /** Nuestros valores para MSH-3 / MSH-4 en la respuesta. */
    public final String sendingApp;
    public final String sendingFacility;
    /** Codificación del canal MLLP (UTF-8 o ISO-8859-1) y su nombre HL7 para MSH-18. */
    public final java.nio.charset.Charset hl7Charset;
    public final String hl7CharsetName;
    /** MLLP sobre TLS (usa javax.net.ssl.keyStore). */
    public final boolean tls;

    private final Map<String, String> source;

    /**
     * Tipo de identificador HL7 (PID-3.5) -> system FHIR.
     * También se acepta la autoridad (PID-3.4.1) como llave.
     */
    public final Map<String, String> typeToSystem = new LinkedHashMap<>();
    /** system FHIR -> autoridad asignadora para PID-3.4 en la respuesta. */
    public final Map<String, String> systemToAuthority = new LinkedHashMap<>();

    public Config() {
        this(System.getenv());
    }

    /** Permite pasar la configuración explícita (pruebas). */
    public Config(Map<String, String> source) {
        this.source = source;
        this.fhirBaseUrl = stripSlash(env("FHIR_BASE_URL", "http://localhost:8080/fhir"));
        this.fhirAuthHeader = authHeader();
        this.mllpPort = Integer.parseInt(env("MLLP_PORT", "2575"));
        this.fhirTimeoutSeconds = Integer.parseInt(env("FHIR_TIMEOUT_SECONDS", "10"));
        this.defaultLimit = Integer.parseInt(env("DEFAULT_LIMIT", "10"));
        this.sendingApp = env("HL7_SENDING_APP", "HRO_PDQ");
        this.sendingFacility = env("HL7_SENDING_FACILITY", "HRO");
        this.hl7Charset = java.nio.charset.Charset.forName(env("HL7_CHARSET", "UTF-8"));
        this.hl7CharsetName = hl7Charset.name().equalsIgnoreCase("UTF-8") ? "UNICODE UTF-8" : "8859/1";
        this.tls = Boolean.parseBoolean(env("MLLP_TLS", "false"));

        String sysMr = env("SYSTEM_HISTORIA_CLINICA", "http://hro.gob.gt/historia-clinica");
        String sysCui = env("SYSTEM_DPI", "http://renap.gob.gt/cui");

        // Historia clínica
        typeToSystem.put("MR", sysMr);
        typeToSystem.put("HRO", sysMr);
        // DPI / CUI: aceptamos los códigos más comunes
        typeToSystem.put("NI", sysCui);
        typeToSystem.put("NNGTM", sysCui);
        typeToSystem.put("NN", sysCui);
        typeToSystem.put("DPI", sysCui);
        typeToSystem.put("CUI", sysCui);
        typeToSystem.put("RENAP", sysCui);

        systemToAuthority.put(sysMr, "HRO");
        systemToAuthority.put(sysCui, "RENAP");
    }

    /** FHIR_AUTH_HEADER tiene prioridad; si no, arma Basic con FHIR_USERNAME / FHIR_PASSWORD. */
    private String authHeader() {
        String header = env("FHIR_AUTH_HEADER", "");
        if (!header.isEmpty()) {
            return header;
        }
        String user = env("FHIR_USERNAME", "");
        if (user.isEmpty()) {
            return "";
        }
        // La contraseña no se recorta: puede tener espacios al inicio o al final
        String pass = source.getOrDefault("FHIR_PASSWORD", "");
        String token = java.util.Base64.getEncoder().encodeToString(
                (user + ":" + pass).getBytes(java.nio.charset.StandardCharsets.UTF_8));
        return "Basic " + token;
    }

    private String env(String name, String def) {
        String v = source.get(name);
        return (v == null || v.isBlank()) ? def : v.trim();
    }

    private static String stripSlash(String s) {
        return s.endsWith("/") ? s.substring(0, s.length() - 1) : s;
    }
}
