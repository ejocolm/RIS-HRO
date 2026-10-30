package gt.gob.hro.pdq;

import ca.uhn.hl7v2.DefaultHapiContext;
import ca.uhn.hl7v2.HapiContext;
import ca.uhn.hl7v2.app.HL7Service;
import ca.uhn.hl7v2.parser.CanonicalModelClassFactory;
import ca.uhn.hl7v2.validation.impl.ValidationContextFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class App {

    private static final Logger log = LoggerFactory.getLogger(App.class);

    public static void main(String[] args) throws Exception {
        Config cfg = new Config();
        HL7Service server = start(cfg);
        Runtime.getRuntime().addShutdownHook(new Thread(server::stopAndWait));
        log.info("Mediador PDQ escuchando MLLP{} en :{} -> facade {} (charset {})",
                cfg.tls ? "/TLS" : "", cfg.mllpPort, cfg.fhirBaseUrl, cfg.hl7Charset);
    }

    /** Arranca el servidor MLLP; también lo usan las pruebas. */
    public static HL7Service start(Config cfg) throws InterruptedException {
        // Codificación del canal MLLP (UTF-8 por defecto, para tildes y ñ)
        System.setProperty("ca.uhn.hl7v2.llp.charset", cfg.hl7Charset.name());

        HapiContext ctx = new DefaultHapiContext();
        // Acepta 2.3, 2.4, 2.5... y los interpreta con estructuras v2.5
        ctx.setModelClassFactory(new CanonicalModelClassFactory("2.5"));
        // Los sistemas reales rara vez cumplen la validación estricta
        ctx.setValidationContext(ValidationContextFactory.noValidation());
        // MSH-10 en memoria (20 caracteres, límite de v2.5). El generador por
        // defecto de HAPI escribe un archivo "id_file" en el directorio actual.
        ctx.getParserConfiguration().setIdGenerator(
                () -> java.util.UUID.randomUUID().toString().replace("-", "").substring(0, 20));

        // TLS: usa el keystore de javax.net.ssl.keyStore (ver README)
        HL7Service server = ctx.newServer(cfg.mllpPort, cfg.tls);
        server.registerApplication("*", "*", new PdqApplication(cfg, new FhirClient(cfg), ctx));
        server.startAndWait();
        return server;
    }
}
