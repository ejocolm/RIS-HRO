package gt.gob.hro.pdq;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

/**
 * Cliente mínimo del facade FHIR: solo GET /Patient?identifier=system|value
 */
public final class FhirClient {

    private final Config cfg;
    private final HttpClient http;
    private final ObjectMapper mapper = new ObjectMapper();

    public FhirClient(Config cfg) {
        this.cfg = cfg;
        this.http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(cfg.fhirTimeoutSeconds))
                .build();
    }

    public List<JsonNode> searchByIdentifier(String system, String value, int count) throws Exception {
        String token = URLEncoder.encode(system + "|" + value, StandardCharsets.UTF_8);
        URI uri = URI.create(cfg.fhirBaseUrl + "/Patient?identifier=" + token + "&_count=" + count);

        HttpRequest.Builder req = HttpRequest.newBuilder(uri)
                .timeout(Duration.ofSeconds(cfg.fhirTimeoutSeconds))
                .header("Accept", "application/fhir+json")
                .GET();
        if (!cfg.fhirAuthHeader.isEmpty()) {
            req.header("Authorization", cfg.fhirAuthHeader);
        }

        HttpResponse<String> resp = http.send(req.build(), HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        if (resp.statusCode() == 404) {
            return List.of();
        }
        if (resp.statusCode() / 100 != 2) {
            throw new IllegalStateException("Facade FHIR respondió HTTP " + resp.statusCode() + " para " + uri);
        }

        JsonNode bundle = mapper.readTree(resp.body());
        List<JsonNode> patients = new ArrayList<>();
        for (JsonNode entry : bundle.path("entry")) {
            JsonNode res = entry.path("resource");
            if ("Patient".equals(res.path("resourceType").asText())) {
                patients.add(res);
            }
        }
        return patients;
    }
}
