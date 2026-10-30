package gt.gob.hro.pdq;

import ca.uhn.hl7v2.HL7Exception;
import ca.uhn.hl7v2.model.v25.segment.QPD;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Parámetros de búsqueda de QPD-3 en formato IHE PDQ.
 *
 * QPD-3 se declara como Varies en HAPI, así que se lee del segmento codificado:
 * "@PID.3.1^837871~@PID.3.5^MR" -> {"@PID.3.1":"837871", "@PID.3.5":"MR"}
 */
public final class QpdParams {

    /** Valor del identificador buscado (ya normalizado). */
    public final String value;
    /** Tipo (PID-3.5) o autoridad (PID-3.4.1); vacío si no vino ninguno. */
    public final String typeOrAuthority;

    private QpdParams(String value, String typeOrAuthority) {
        this.value = value;
        this.typeOrAuthority = typeOrAuthority;
    }

    public static QpdParams from(QPD qpd) throws HL7Exception {
        String encoded = qpd.encode();
        String[] fields = encoded.split("\\|", -1);
        String qpd3 = fields.length > 3 ? fields[3] : "";

        Map<String, String> params = new LinkedHashMap<>();
        for (String rep : qpd3.split("~")) {
            int caret = rep.indexOf('^');
            if (caret <= 0) continue;
            params.put(rep.substring(0, caret).trim().toUpperCase(), unescape(rep.substring(caret + 1)).trim());
        }

        String value = params.getOrDefault("@PID.3.1", "");
        String type = params.getOrDefault("@PID.3.5", "");
        String authority = params.getOrDefault("@PID.3.4.1", params.getOrDefault("@PID.3.4", ""));

        // Forma compacta: @PID.3^837871^^^HRO^MR
        if (value.isEmpty() && params.containsKey("@PID.3")) {
            String[] c = params.get("@PID.3").split("\\^", -1);
            value = c.length > 0 ? c[0] : "";
            if (authority.isEmpty() && c.length > 3) authority = c[3].split("&")[0];
            if (type.isEmpty() && c.length > 4) type = c[4];
        }

        // Normaliza: "3593 74514 0801" -> "3593745140801"
        value = value.replaceAll("[\\s-]", "");
        String key = (!type.isEmpty() ? type : authority).toUpperCase();
        return new QpdParams(value, key);
    }

    private static String unescape(String s) {
        return s.replace("\\F\\", "|")
                .replace("\\S\\", "^")
                .replace("\\T\\", "&")
                .replace("\\R\\", "~")
                .replace("\\E\\", "\\");
    }
}
