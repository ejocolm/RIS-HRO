USE RIS_HRO;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================
   RIS_HRO
   CATÁLOGO INICIAL DE PARTES DEL CUERPO
   Uso principal: Rayos X y Ultrasonido

   - Es seguro ejecutarlo más de una vez.
   - No elimina registros existentes.
   - No duplica un código ni un nombre ya registrado.
   ============================================================ */

DECLARE @Partes TABLE
(
    IdParteCuerpo VARCHAR(20) NOT NULL,
    NombreParte VARCHAR(120) NOT NULL,
    Descripcion VARCHAR(250) NULL
);

INSERT INTO @Partes (IdParteCuerpo, NombreParte, Descripcion)
VALUES
/* -------------------------
   CABEZA Y CUELLO
   ------------------------- */
('PC001', 'Cabeza',                    'Región general de cabeza; aplicable a estudios radiográficos o ultrasonográficos cuando corresponda.'),
('PC002', 'Cráneo',                    'Cráneo. Principalmente utilizado en estudios de rayos X.'),
('PC003', 'Senos paranasales',         'Región de senos paranasales. Principalmente rayos X.'),
('PC004', 'Huesos propios de la nariz','Región nasal ósea. Principalmente rayos X.'),
('PC005', 'Mandíbula',                 'Mandíbula. Principalmente rayos X.'),
('PC006', 'Cuello',                    'Región cervical anterior y lateral. Puede utilizarse en rayos X y ultrasonido.'),
('PC007', 'Tiroides',                  'Glándula tiroides. Principalmente ultrasonido.'),
('PC008', 'Región cervical derecha',   'Lado derecho del cuello. Principalmente ultrasonido.'),
('PC009', 'Región cervical izquierda', 'Lado izquierdo del cuello. Principalmente ultrasonido.'),

/* -------------------------
   TÓRAX
   ------------------------- */
('PC010', 'Tórax',                     'Región torácica. Principalmente rayos X.'),
('PC011', 'Costillas derechas',        'Parrilla costal derecha. Principalmente rayos X.'),
('PC012', 'Costillas izquierdas',      'Parrilla costal izquierda. Principalmente rayos X.'),
('PC013', 'Esternón',                  'Esternón. Principalmente rayos X.'),
('PC014', 'Clavícula derecha',         'Clavícula derecha. Principalmente rayos X.'),
('PC015', 'Clavícula izquierda',       'Clavícula izquierda. Principalmente rayos X.'),

/* -------------------------
   COLUMNA
   ------------------------- */
('PC016', 'Columna cervical',          'Segmento cervical de la columna vertebral. Principalmente rayos X.'),
('PC017', 'Columna torácica',          'Segmento torácico/dorsal de la columna vertebral. Principalmente rayos X.'),
('PC018', 'Columna lumbar',            'Segmento lumbar de la columna vertebral. Principalmente rayos X.'),
('PC019', 'Columna lumbosacra',        'Región lumbosacra. Principalmente rayos X.'),
('PC020', 'Sacro y cóccix',            'Región sacrococcígea. Principalmente rayos X.'),

/* -------------------------
   MIEMBROS SUPERIORES
   ------------------------- */
('PC021', 'Hombro derecho',            'Hombro derecho. Rayos X y ultrasonido musculoesquelético.'),
('PC022', 'Hombro izquierdo',          'Hombro izquierdo. Rayos X y ultrasonido musculoesquelético.'),
('PC023', 'Brazo derecho',             'Brazo derecho.'),
('PC024', 'Brazo izquierdo',           'Brazo izquierdo.'),
('PC025', 'Codo derecho',              'Codo derecho. Rayos X y ultrasonido musculoesquelético.'),
('PC026', 'Codo izquierdo',            'Codo izquierdo. Rayos X y ultrasonido musculoesquelético.'),
('PC027', 'Antebrazo derecho',         'Antebrazo derecho.'),
('PC028', 'Antebrazo izquierdo',       'Antebrazo izquierdo.'),
('PC029', 'Muñeca derecha',            'Muñeca derecha. Rayos X y ultrasonido musculoesquelético.'),
('PC030', 'Muñeca izquierda',          'Muñeca izquierda. Rayos X y ultrasonido musculoesquelético.'),
('PC031', 'Mano derecha',              'Mano derecha.'),
('PC032', 'Mano izquierda',            'Mano izquierda.'),
('PC033', 'Dedos de mano derecha',     'Dedos de la mano derecha.'),
('PC034', 'Dedos de mano izquierda',   'Dedos de la mano izquierda.'),
('PC035', 'Miembro superior derecho',  'Miembro superior derecho; útil para estudios ultrasonográficos o vasculares.'),
('PC036', 'Miembro superior izquierdo','Miembro superior izquierdo; útil para estudios ultrasonográficos o vasculares.'),

/* -------------------------
   ABDOMEN Y PELVIS
   ------------------------- */
('PC037', 'Abdomen',                   'Región abdominal general. Rayos X y ultrasonido.'),
('PC038', 'Abdomen superior',          'Región superior del abdomen. Principalmente ultrasonido.'),
('PC039', 'Pelvis',                    'Región pélvica. Rayos X y ultrasonido.'),
('PC040', 'Hígado',                    'Hígado. Principalmente ultrasonido.'),
('PC041', 'Vesícula biliar',           'Vesícula biliar. Principalmente ultrasonido.'),
('PC042', 'Páncreas',                  'Páncreas. Principalmente ultrasonido.'),
('PC043', 'Bazo',                      'Bazo. Principalmente ultrasonido.'),
('PC044', 'Riñón derecho',             'Riñón derecho. Principalmente ultrasonido.'),
('PC045', 'Riñón izquierdo',           'Riñón izquierdo. Principalmente ultrasonido.'),
('PC046', 'Vejiga urinaria',           'Vejiga urinaria. Principalmente ultrasonido.'),
('PC047', 'Útero',                     'Útero. Principalmente ultrasonido.'),
('PC048', 'Ovario derecho',            'Ovario derecho. Principalmente ultrasonido.'),
('PC049', 'Ovario izquierdo',          'Ovario izquierdo. Principalmente ultrasonido.'),
('PC050', 'Próstata',                  'Próstata. Principalmente ultrasonido.'),

/* -------------------------
   MAMA, AXILA Y REGIÓN INGUINAL
   ------------------------- */
('PC051', 'Mama derecha',              'Mama derecha. Principalmente ultrasonido y estudios mamarios.'),
('PC052', 'Mama izquierda',            'Mama izquierda. Principalmente ultrasonido y estudios mamarios.'),
('PC053', 'Ambas mamas',               'Evaluación bilateral de mamas.'),
('PC054', 'Axila derecha',             'Región axilar derecha. Principalmente ultrasonido.'),
('PC055', 'Axila izquierda',           'Región axilar izquierda. Principalmente ultrasonido.'),
('PC056', 'Región inguinal derecha',   'Región inguinal derecha. Principalmente ultrasonido.'),
('PC057', 'Región inguinal izquierda', 'Región inguinal izquierda. Principalmente ultrasonido.'),

/* -------------------------
   GENITALES MASCULINOS
   ------------------------- */
('PC058', 'Testículo derecho',         'Testículo derecho. Principalmente ultrasonido.'),
('PC059', 'Testículo izquierdo',       'Testículo izquierdo. Principalmente ultrasonido.'),
('PC060', 'Escroto',                   'Región escrotal. Principalmente ultrasonido.'),

/* -------------------------
   MIEMBROS INFERIORES
   ------------------------- */
('PC061', 'Cadera derecha',            'Cadera derecha. Rayos X y ultrasonido cuando corresponda.'),
('PC062', 'Cadera izquierda',          'Cadera izquierda. Rayos X y ultrasonido cuando corresponda.'),
('PC063', 'Fémur derecho',             'Fémur derecho. Principalmente rayos X.'),
('PC064', 'Fémur izquierdo',           'Fémur izquierdo. Principalmente rayos X.'),
('PC065', 'Rodilla derecha',           'Rodilla derecha. Rayos X y ultrasonido musculoesquelético.'),
('PC066', 'Rodilla izquierda',         'Rodilla izquierda. Rayos X y ultrasonido musculoesquelético.'),
('PC067', 'Pierna derecha',            'Pierna derecha.'),
('PC068', 'Pierna izquierda',          'Pierna izquierda.'),
('PC069', 'Tobillo derecho',           'Tobillo derecho. Rayos X y ultrasonido musculoesquelético.'),
('PC070', 'Tobillo izquierdo',         'Tobillo izquierdo. Rayos X y ultrasonido musculoesquelético.'),
('PC071', 'Pie derecho',               'Pie derecho.'),
('PC072', 'Pie izquierdo',             'Pie izquierdo.'),
('PC073', 'Dedos de pie derecho',      'Dedos del pie derecho.'),
('PC074', 'Dedos de pie izquierdo',    'Dedos del pie izquierdo.'),
('PC075', 'Calcáneo derecho',          'Calcáneo derecho. Principalmente rayos X.'),
('PC076', 'Calcáneo izquierdo',        'Calcáneo izquierdo. Principalmente rayos X.'),
('PC077', 'Miembro inferior derecho',  'Miembro inferior derecho; útil para ultrasonido vascular o de partes blandas.'),
('PC078', 'Miembro inferior izquierdo','Miembro inferior izquierdo; útil para ultrasonido vascular o de partes blandas.'),

/* -------------------------
   PARTES BLANDAS
   ------------------------- */
('PC079', 'Tejidos blandos de cabeza', 'Tejidos blandos de la cabeza. Principalmente ultrasonido.'),
('PC080', 'Tejidos blandos de cuello', 'Tejidos blandos del cuello. Principalmente ultrasonido.'),
('PC081', 'Tejidos blandos de tórax',  'Tejidos blandos del tórax. Principalmente ultrasonido.'),
('PC082', 'Tejidos blandos de abdomen','Tejidos blandos del abdomen. Principalmente ultrasonido.'),
('PC083', 'Tejidos blandos de pelvis', 'Tejidos blandos de pelvis. Principalmente ultrasonido.'),
('PC084', 'Tejidos blandos de miembro superior derecho',   'Partes blandas del miembro superior derecho.'),
('PC085', 'Tejidos blandos de miembro superior izquierdo', 'Partes blandas del miembro superior izquierdo.'),
('PC086', 'Tejidos blandos de miembro inferior derecho',   'Partes blandas del miembro inferior derecho.'),
('PC087', 'Tejidos blandos de miembro inferior izquierdo', 'Partes blandas del miembro inferior izquierdo.');

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.CAT_PARTES_CUERPO
    (
        IdParteCuerpo,
        NombreParte,
        Descripcion,
        Activo
    )
    SELECT
        P.IdParteCuerpo,
        P.NombreParte,
        P.Descripcion,
        1
    FROM @Partes P
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.CAT_PARTES_CUERPO C
        WHERE C.IdParteCuerpo = P.IdParteCuerpo
           OR C.NombreParte = P.NombreParte
    );

    DECLARE @Insertados INT = @@ROWCOUNT;

    COMMIT;

    PRINT CONCAT('Registros nuevos insertados: ', @Insertados);
    PRINT 'Catálogo de partes del cuerpo cargado correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK;

    THROW;
END CATCH;
GO

/* Verificación */
SELECT
    IdParteCuerpo,
    NombreParte,
    Descripcion,
    Activo
FROM dbo.CAT_PARTES_CUERPO
ORDER BY IdParteCuerpo;
GO
