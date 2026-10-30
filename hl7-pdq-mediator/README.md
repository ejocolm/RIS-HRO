# Mediador HL7 v2 PDQ → FHIR Patient

Permite que un sistema que solo habla **HL7 v2** busque pacientes en el facade FHIR
por **número de historia clínica** o por **DPI (CUI)**.

```
Sistema externo ──QBP^Q22 (MLLP/TCP :2575)──▶ mediador ──GET /Patient?identifier=…──▶ OpenHIM / facade FHIR
                ◀──────────RSP^K22─────────────        ◀──────────Bundle──────────────
```

- Implementa la transacción IHE PDQ (ITI-21): consulta `QBP^Q22`, respuesta `RSP^K22`.
- Usa **HAPI HL7v2 2.6.0**: `HL7Service` para MLLP (con TLS opcional) y las estructuras
  tipadas v2.5 (`QBP_Q21`, `RSP_K21`, `PID`…). HAPI escapa los delimitadores automáticamente.
- Acepta mensajes 2.3, 2.4 o 2.5 (se interpretan con estructuras 2.5) y responde con la
  misma versión que recibió.
- Java 17+.

## Estructura

| Clase | Qué hace |
|---|---|
| `App` | Configura HAPI y arranca el servidor MLLP |
| `PdqApplication` | Recibe el `QBP^Q22`, consulta el facade y arma el `RSP^K22` o el error |
| `QpdParams` | Lee los parámetros de QPD-3 |
| `PidMapper` | FHIR `Patient` → segmento `PID` |
| `FhirClient` | `GET /Patient?identifier=system\|valor` |
| `Config` | Variables de entorno |

## Consultas soportadas

| Búsqueda | QPD-3 |
|---|---|
| Historia clínica | `@PID.3.1^837871~@PID.3.5^MR` |
| DPI | `@PID.3.1^3593745140801~@PID.3.5^NI` (también acepta `NNGTM`, `NN`, `DPI`, `CUI`) |
| Por autoridad | `@PID.3.1^837871~@PID.3.4.1^HRO` (o `RENAP`) |
| Forma compacta | `@PID.3^837871^^^HRO^MR` |
| Sin tipo | `@PID.3.1^3593745140801` → busca en ambos sistemas |

Los espacios y guiones del valor se eliminan (`3593 74514 0801` → `3593745140801`).
`RCP-2` limita la cantidad de resultados (por defecto 10).

Ejemplo de consulta:

```
MSH|^~\&|SIS_EXT|HOSPX|HRO_PDQ|HRO|20261026103000||QBP^Q22^QBP_Q21|Q0001|P|2.5
QPD|IHE PDQ Query|Q0001|@PID.3.1^837871~@PID.3.5^MR
RCP|I|10^RD
```

Respuesta:

```
MSH|^~\&|HRO_PDQ|HRO|SIS_EXT|HOSPX|20261026110654.005-0600||RSP^K22^RSP_K21|5bf85351147643fe9e4b|P|2.5||||||UNICODE UTF-8
MSA|AA|Q0001
QAK|Q0001|OK|IHE PDQ Query|1|1|0
QPD|IHE PDQ Query|Q0001|@PID.3.1^837871~@PID.3.5^MR
PID|1||837871^^^HRO^MR~3593745140801^^^RENAP^NI||AJUCUM CUA^ADOLFO^MARTIN|JUANA OLIVIA CUA CASTRO|19970528|M|||CANTON COXOM^^Totonicapán^TOTONICAPAN^^Guatemala
```

### Respuestas posibles

| Caso | MSA | QAK-2 | ERR |
|---|---|---|---|
| Encontrado | `AA` | `OK` | — |
| No encontrado | `AA` | `NF` | — |
| Falta el identificador | `AE` | `AE` | `101` |
| Tipo de identificador desconocido | `AE` | `AE` | `103` |
| Facade caído / error HTTP | `AE` | `AE` | `207` |
| Mensaje que no es `QBP^Q22` | `AR` (ACK generado por HAPI) | — | `200` |

## Mapeo Patient → PID

| FHIR | PID | Nota |
|---|---|---|
| `identifier[]` | PID-3 | `valor^^^Autoridad^Tipo`; tipo tomado de `identifier.type` (MR / NI) |
| `name` (use=official) | PID-5 | `family^given[0]^resto de given` |
| ext. `nombre-madre` | PID-6 | Texto completo en el primer componente (apellido) |
| `birthDate` | PID-7 | `AAAAMMDD` |
| `gender` | PID-8 | `M` / `F` / `O` / `U` |
| `address[]` | PID-11 | `line[0]^line[1..]^city^state o district^postalCode^country` |
| `telecom` (phone) | PID-13 | Solo teléfonos del paciente, no de `contact[]` |
| `deceased[x]` | PID-29 / PID-30 | |

El mapeo está en `PidMapper`; ajústalo a lo que acuerden con el otro sistema.

## Configuración (variables de entorno)

| Variable | Default | Descripción |
|---|---|---|
| `FHIR_BASE_URL` | `http://localhost:8080/fhir` | URL base del facade (o del router de OpenHIM) |
| `FHIR_USERNAME` / `FHIR_PASSWORD` | — | Usuario y contraseña del cliente OpenHIM; el mediador arma el header `Basic` |
| `FHIR_AUTH_HEADER` | — | Valor completo del header `Authorization` (p. ej. `Bearer …`); tiene prioridad sobre usuario/contraseña |
| `SYSTEM_HISTORIA_CLINICA` | `http://hro.gob.gt/historia-clinica` | system FHIR de la historia clínica |
| `SYSTEM_DPI` | `http://renap.gob.gt/cui` | system FHIR del DPI |
| `MLLP_PORT` | `2575` | Puerto MLLP |
| `HL7_CHARSET` | `UTF-8` | `ISO-8859-1` si el otro sistema no maneja UTF-8 (tildes, ñ) |
| `HL7_SENDING_APP` / `HL7_SENDING_FACILITY` | `HRO_PDQ` / `HRO` | MSH-3 / MSH-4 de las respuestas |
| `DEFAULT_LIMIT` | `10` | Máximo de resultados si no viene RCP-2 |
| `FHIR_TIMEOUT_SECONDS` | `10` | Timeout de las llamadas al facade |
| `MLLP_TLS` | `false` | MLLP sobre TLS (ver abajo) |

## Compilar y ejecutar

```bash
mvn package          # compila y corre las pruebas
FHIR_BASE_URL=https://openhim-qa-router.hro.gob.gt/fhir java -jar target/hl7-pdq-mediator.jar
```

Con Docker:

```bash
docker compose up -d --build
docker logs -f hl7-pdq-mediator
```

## Probar

**Pruebas automáticas:** `mvn test` corre `PdqEndToEndTest`. La prueba levanta un facade
simulado, arranca el mediador y le envía los 7 casos (historia clínica, DPI con espacios,
no encontrado, forma compacta en v2.3, tipo inválido, facade caído y ADT no soportado)
con el cliente MLLP de HAPI.

**Pruebas manuales:** `test/` trae un facade simulado en Python (con el paciente 837871)
y un cliente MLLP:

```bash
python3 test/mock_fhir.py 8099 &
FHIR_BASE_URL=http://127.0.0.1:8099/fhir java -jar target/hl7-pdq-mediator.jar &
python3 test/send_mllp.py 127.0.0.1 2575 test/mensajes/*.hl7
```

Para probar contra el facade real, arranca el mediador con
`FHIR_BASE_URL=https://openhim-qa-router.hro.gob.gt/fhir` y usa el mismo cliente.

## Seguridad

MLLP no tiene autenticación. Antes de producción:

- Abre el puerto 2575 solo a la IP del sistema que consulta (firewall).
- Usa un cliente de OpenHIM propio para este mediador (`FHIR_AUTH_HEADER`), así cada consulta queda registrada en OpenHIM con su origen.
- Si la conexión cruza redes, activa TLS (siempre que el otro sistema lo soporte).

### MLLP sobre TLS

HAPI usa el keystore estándar de Java:

```bash
# Certificado autofirmado de ejemplo (en producción usa uno de tu CA)
keytool -genkeypair -alias mediator -keyalg RSA -keysize 2048 -validity 825 \
  -storetype PKCS12 -keystore certs/mediator.p12 -dname "CN=hl7.hro.gob.gt"

MLLP_TLS=true java \
  -Djavax.net.ssl.keyStore=certs/mediator.p12 \
  -Djavax.net.ssl.keyStorePassword=CAMBIAR \
  -Djavax.net.ssl.keyStoreType=PKCS12 \
  -jar target/hl7-pdq-mediator.jar
```

En Docker, monta `certs/` y agrega esos `-D` a `JAVA_OPTS` (hay un ejemplo comentado en
`docker-compose.yml`). El otro sistema debe confiar en el certificado.
