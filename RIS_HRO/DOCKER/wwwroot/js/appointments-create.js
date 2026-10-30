(() => {
    'use strict';

    const el = id => document.getElementById(id);
    const studies = new Map();
    const bodyParts = Array.isArray(window.bodyParts) ? window.bodyParts : [];

    let activeBodyPartStudyCode = null;

    const appointmentDateInput = el('appointmentDate');
    const appointmentTimeInput = el('appointmentTime');
    const mobileStudyWrapper = el('mobileStudyWrapper');
    const mobileStudyInput = el('isMobile');
    const availabilityColumn = el('availabilityColumn');
    const appointmentLayout = el('appointmentLayout');
    const capacityNote = el('capacityNote');
    const registrationTypeInputs = [
        ...document.querySelectorAll('input[name="TipoRegistro"]')
    ];

    function isDailyRequest() {
        const selected = registrationTypeInputs.find(input => input.checked);
        return selected?.value === 'SOLICITUD_DIA';
    }

    function setCurrentRequestDateTime() {
        const now = new Date();

        if (appointmentDateInput) {
            appointmentDateInput.value = formatLocalDate(now);
        }

        if (appointmentTimeInput) {
            const hours = String(now.getHours()).padStart(2, '0');
            const minutes = String(now.getMinutes()).padStart(2, '0');
            appointmentTimeInput.value = `${hours}:${minutes}`;
        }

        currentMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    }

    function applyRegistrationTypeUi(initializeDateTime = false) {
        const dailyRequest = isDailyRequest();

        mobileStudyWrapper?.classList.toggle('d-none', !dailyRequest);
        availabilityColumn?.classList.toggle('d-none', dailyRequest);
        appointmentLayout?.classList.toggle('request-mode', dailyRequest);

        if (!dailyRequest) {
            if (mobileStudyInput) mobileStudyInput.checked = false;

            if (capacityNote) {
                capacityNote.innerHTML =
                    '<i class="bi bi-info-circle"></i> ' +
                    'Cada estudio debe tener al menos una parte del cuerpo. ' +
                    'Aunque seleccione varias partes, el estudio consume un solo cupo.';
            }
        } else {
            if (capacityNote) {
                capacityNote.innerHTML =
                    '<i class="bi bi-info-circle"></i> ' +
                    'Las solicitudes del día no consumen cupo de agenda.';
            }

            if (initializeDateTime) setCurrentRequestDateTime();
        }
    }

    let currentMonth = new Date();

    if (appointmentDateInput?.value) {
        const initialDate = new Date(`${appointmentDateInput.value}T00:00:00`);
        if (!Number.isNaN(initialDate.getTime())) {
            currentMonth = initialDate;
        }
    }

    currentMonth = new Date(
        currentMonth.getFullYear(),
        currentMonth.getMonth(),
        1
    );

    registrationTypeInputs.forEach(input => {
        input.addEventListener('change', async () => {
            const becameDailyRequest = isDailyRequest();
            applyRegistrationTypeUi(becameDailyRequest);

            if (!becameDailyRequest) {
                await loadAvailability();
            }
        });
    });

    let availability = { days: [], details: [] };

    /* =========================================================
       PACIENTE
       ========================================================= */

    async function searchPatient() {
        const patientId = el('patientId');
        const patientMessage = el('patientMessage');
        const patientSummary = el('patientSummary');
        const manualPatientSection = el('manualPatientSection');

        if (!patientId || !patientMessage) return;

        const id = patientId.value.trim();

        patientMessage.textContent = '';
        patientSummary?.classList.add('d-none');
        manualPatientSection?.classList.add('d-none');

        if (!id) {
            patientMessage.textContent = 'Ingrese el ID del paciente.';
            return;
        }

        patientMessage.textContent = 'Consultando paciente...';

        try {
            const response = await fetch(`?handler=Patient&id=${encodeURIComponent(id)}`);
            if (!response.ok) throw new Error(`HTTP ${response.status}`);

            const data = await response.json();
            patientMessage.textContent = data.message || '';

            if (data.found && data.patient) {
                const p = data.patient;

                if (el('patientFirstName')) el('patientFirstName').value = p.primerNombre || '';
                if (el('patientSecondName')) el('patientSecondName').value = p.segundoNombre || '';
                if (el('patientFirstLastName')) el('patientFirstLastName').value = p.primerApellido || '';
                if (el('patientSecondLastName')) el('patientSecondLastName').value = p.segundoApellido || '';
                if (el('patientBirthDate')) {
                    el('patientBirthDate').value = p.fechaNacimiento
                        ? p.fechaNacimiento.substring(0, 10)
                        : '';
                }
                if (el('patientSex')) el('patientSex').value = p.sexo || '';
                if (el('patientPhone')) el('patientPhone').value = p.telefono || '';

                if (el('patientSummaryName')) {
                    el('patientSummaryName').textContent =
                        p.nombreCompleto ||
                        [p.primerNombre, p.segundoNombre, p.primerApellido, p.segundoApellido]
                            .filter(Boolean)
                            .join(' ');
                }

                if (el('patientSummarySource')) {
                    el('patientSummarySource').textContent =
                        data.source === 'HOSPITAL'
                            ? 'Información obtenida del sistema institucional.'
                            : 'Información obtenida de la base local.';
                }

                patientSummary?.classList.remove('d-none');
            } else {
                manualPatientSection?.classList.remove('d-none');
            }
        } catch (error) {
            console.error('Error al consultar paciente:', error);
            patientMessage.textContent =
                'No fue posible consultar la información del paciente.';
            manualPatientSection?.classList.remove('d-none');
        }
    }

    const btnSearchPatient = el('btnSearchPatient');
    const patientIdInput = el('patientId');

    btnSearchPatient?.addEventListener('click', searchPatient);

    if (patientIdInput && btnSearchPatient) {
        patientIdInput.addEventListener('keydown', event => {
            if (event.key === 'Enter') {
                event.preventDefault();
                searchPatient();
            }
        });
    }

    /* =========================================================
       ESTUDIOS Y PARTES DEL CUERPO
       ========================================================= */

    function normalizeStudy(study) {
        return {
            idPrueba: study?.idPrueba || '',
            nombrePrueba: study?.nombrePrueba || '',
            nombreCategoria: study?.nombreCategoria || '',
            tecnico: study?.tecnico || null,
            partesCuerpo: Array.isArray(study?.partesCuerpo)
                ? study.partesCuerpo.map(part => ({
                    idParteCuerpo: part.idParteCuerpo || '',
                    nombreParte: part.nombreParte || ''
                }))
                : []
        };
    }

    function updateStudyHidden() {
        const idsHidden = el('studyIdsCsv');
        const bodyPartsHidden = el('studyBodyPartsJson');

        if (idsHidden) {
            idsHidden.value = [...studies.keys()].join(',');
        }

        if (bodyPartsHidden) {
            const relations = [];

            for (const study of studies.values()) {
                for (const part of study.partesCuerpo || []) {
                    if (!part.idParteCuerpo) continue;

                    relations.push({
                        idPrueba: study.idPrueba,
                        idParteCuerpo: part.idParteCuerpo
                    });
                }
            }

            bodyPartsHidden.value = JSON.stringify(relations);
        }
    }

    function bodyPartSummary(study) {
        const parts = study.partesCuerpo || [];

        if (parts.length === 0) {
            return `
                <div class="text-danger small mb-1">
                    <i class="bi bi-exclamation-circle"></i>
                    Pendiente
                </div>`;
        }

        return `
            <div class="d-flex flex-wrap gap-1 mb-1">
                ${parts.map(part => `
                    <span class="badge text-bg-light border">
                        ${escapeHtml(part.nombreParte)}
                    </span>`).join('')}
            </div>`;
    }

    function renderStudies() {
        const body = el('studiesBody');
        if (!body) return;

        body.innerHTML = '';

        const showReportColumn = window.showReportColumn === true;
        const columnCount = showReportColumn ? 7 : 6;

        if (studies.size === 0) {
            body.innerHTML = `
                <tr>
                    <td colspan="${columnCount}" class="text-center text-muted py-4">
                        Agregue por lo menos un estudio.
                    </td>
                </tr>`;
        } else {
            for (const study of studies.values()) {
                const row = document.createElement('tr');

                row.innerHTML = `
                    <td><strong>${escapeHtml(study.idPrueba)}</strong></td>
                    <td>${escapeHtml(study.nombrePrueba)}</td>
                    <td>${escapeHtml(study.nombreCategoria)}</td>
                    <td style="min-width:220px">
                        ${bodyPartSummary(study)}
                        <button type="button"
                                class="btn-ris-small study-body-parts"
                                data-code="${escapeHtml(study.idPrueba)}">
                            <i class="bi bi-person-bounding-box"></i>
                            ${study.partesCuerpo?.length ? 'Modificar' : 'Seleccionar'}
                        </button>
                    </td>
                    <td class="text-muted">
                        ${escapeHtml(study.tecnico || 'Pendiente asignar')}
                    </td>
                    ${showReportColumn ? `
                    <td class="text-muted">
                        ${escapeHtml(window.reportUnavailableText || 'Solicitud no atendida')}
                    </td>` : ''}
                    <td>
                        <button type="button"
                                class="study-remove"
                                data-code="${escapeHtml(study.idPrueba)}">
                            <i class="bi bi-trash"></i> Eliminar
                        </button>
                    </td>`;

                body.appendChild(row);
            }
        }

        body.querySelectorAll('.study-remove').forEach(button => {
            button.addEventListener('click', async () => {
                const code = button.dataset.code;
                if (!code) return;

                studies.delete(code);
                updateStudyHidden();
                renderStudies();
                await loadAvailability();
            });
        });

        body.querySelectorAll('.study-body-parts').forEach(button => {
            button.addEventListener('click', () => {
                const code = button.dataset.code;
                if (code) openBodyPartModal(code);
            });
        });

        updateStudyHidden();
    }

    async function addStudyByCode(code) {
        const studyCodeInput = el('studyCode');
        code = (code || '').trim().toUpperCase();

        if (!code) return;

        if (studies.has(code)) {
            if (studyCodeInput) studyCodeInput.value = '';
            openBodyPartModal(code);
            return;
        }

        try {
            const response = await fetch(`?handler=Study&code=${encodeURIComponent(code)}`);
            if (!response.ok) throw new Error(`HTTP ${response.status}`);

            const data = await response.json();

            if (!data.found || !data.study) {
                alert('No se encontró un estudio activo con ese código.');
                return;
            }

            const study = normalizeStudy(data.study);
            studies.set(study.idPrueba, study);

            if (studyCodeInput) studyCodeInput.value = '';

            renderStudies();
            await loadAvailability();
            openBodyPartModal(study.idPrueba);
        } catch (error) {
            console.error('Error al buscar el estudio:', error);
            alert('No fue posible consultar el estudio.');
        }
    }

    const btnAddStudyCode = el('btnAddStudyCode');
    const studyCodeInput = el('studyCode');

    if (btnAddStudyCode && studyCodeInput) {
        btnAddStudyCode.addEventListener('click', () => {
            addStudyByCode(studyCodeInput.value);
        });

        studyCodeInput.addEventListener('keydown', event => {
            if (event.key === 'Enter') {
                event.preventDefault();
                addStudyByCode(event.currentTarget.value);
            }
        });
    }

    /* =========================================================
       MODAL PARTES DEL CUERPO
       ========================================================= */

    function openBodyPartModal(studyCode) {
        const study = studies.get(studyCode);
        const modalElement = el('bodyPartModal');

        if (!study || !modalElement) return;

        activeBodyPartStudyCode = studyCode;

        if (el('bodyPartStudyTitle')) {
            el('bodyPartStudyTitle').textContent =
                `${study.idPrueba} - ${study.nombrePrueba}`;
        }

        if (el('bodyPartSearchText')) {
            el('bodyPartSearchText').value = '';
        }

        renderBodyPartOptions();

        if (window.bootstrap?.Modal) {
            bootstrap.Modal.getOrCreateInstance(modalElement).show();
        }
    }

    function renderBodyPartOptions() {
        const container = el('bodyPartOptions');
        const empty = el('bodyPartEmpty');

        if (!container || !activeBodyPartStudyCode) return;

        const study = studies.get(activeBodyPartStudyCode);
        if (!study) return;

        const search = (el('bodyPartSearchText')?.value || '')
            .trim()
            .toLowerCase();

        const selectedIds = new Set(
            (study.partesCuerpo || []).map(x => x.idParteCuerpo)
        );

        const filtered = bodyParts.filter(part => {
            if (!search) return true;

            return (part.idParteCuerpo || '').toLowerCase().includes(search) ||
                   (part.nombreParte || '').toLowerCase().includes(search);
        });

        container.innerHTML = '';

        empty?.classList.toggle('d-none', filtered.length !== 0);

        filtered.forEach(part => {
            const col = document.createElement('div');
            col.className = 'col-md-6';

            const inputId = `bodyPart_${safeId(part.idParteCuerpo)}`;

            col.innerHTML = `
                <label class="border rounded-3 p-3 d-flex align-items-start gap-2 w-100 h-100"
                       for="${inputId}"
                       style="cursor:pointer">
                    <input class="form-check-input mt-1 body-part-check"
                           type="checkbox"
                           value="${escapeHtml(part.idParteCuerpo)}"
                           id="${inputId}"
                           ${selectedIds.has(part.idParteCuerpo) ? 'checked' : ''}>
                    <span>
                        <strong class="d-block">${escapeHtml(part.nombreParte)}</strong>
                        <small class="text-muted">${escapeHtml(part.idParteCuerpo)}</small>
                    </span>
                </label>`;

            container.appendChild(col);
        });
    }

    el('bodyPartSearchText')?.addEventListener('input', renderBodyPartOptions);

    el('btnSaveBodyParts')?.addEventListener('click', () => {
        if (!activeBodyPartStudyCode) return;

        const study = studies.get(activeBodyPartStudyCode);
        if (!study) return;

        const checkedIds = [
            ...document.querySelectorAll('#bodyPartOptions .body-part-check:checked')
        ].map(input => input.value);

        if (checkedIds.length === 0) {
            alert('Seleccione por lo menos una parte del cuerpo para este estudio.');
            return;
        }

        study.partesCuerpo = bodyParts
            .filter(part => checkedIds.includes(part.idParteCuerpo))
            .map(part => ({
                idParteCuerpo: part.idParteCuerpo,
                nombreParte: part.nombreParte
            }));

        studies.set(study.idPrueba, study);

        updateStudyHidden();
        renderStudies();

        const modalElement = el('bodyPartModal');
        if (modalElement && window.bootstrap?.Modal) {
            bootstrap.Modal.getOrCreateInstance(modalElement).hide();
        }
    });

    el('bodyPartModal')?.addEventListener('hidden.bs.modal', () => {
        activeBodyPartStudyCode = null;
    });

    /* =========================================================
       BUSCAR ESTUDIO
       ========================================================= */

    async function searchStudies() {
        const searchText = el('studySearchText');
        const body = el('studySearchBody');

        if (!searchText || !body) return;

        const q = searchText.value.trim();

        try {
            const response = await fetch(`?handler=Studies&q=${encodeURIComponent(q)}`);
            if (!response.ok) throw new Error(`HTTP ${response.status}`);

            const data = await response.json();
            body.innerHTML = '';

            data.forEach(rawStudy => {
                const study = normalizeStudy(rawStudy);
                const row = document.createElement('tr');

                row.innerHTML = `
                    <td><strong>${escapeHtml(study.idPrueba)}</strong></td>
                    <td>${escapeHtml(study.nombrePrueba)}</td>
                    <td>${escapeHtml(study.nombreCategoria)}</td>
                    <td class="text-end">
                        <button type="button" class="btn-ris-small">
                            ${studies.has(study.idPrueba) ? 'Seleccionar partes' : 'Agregar'}
                        </button>
                    </td>`;

                row.querySelector('button')?.addEventListener('click', async () => {
                    if (!studies.has(study.idPrueba)) {
                        studies.set(study.idPrueba, study);
                        renderStudies();
                        await loadAvailability();
                    }

                    const studyModalElement = el('studyModal');
                    if (studyModalElement && window.bootstrap?.Modal) {
                        bootstrap.Modal.getOrCreateInstance(studyModalElement).hide();
                    }

                    setTimeout(() => openBodyPartModal(study.idPrueba), 200);
                });

                body.appendChild(row);
            });
        } catch (error) {
            console.error('Error al buscar estudios:', error);

            body.innerHTML = `
                <tr>
                    <td colspan="4" class="text-center text-danger py-3">
                        No fue posible consultar los estudios.
                    </td>
                </tr>`;
        }
    }

    el('studySearchText')?.addEventListener('input', searchStudies);
    el('studyModal')?.addEventListener('shown.bs.modal', searchStudies);

    /* =========================================================
       CALENDARIO Y DISPONIBILIDAD
       ========================================================= */

    el('prevMonth')?.addEventListener('click', async () => {
        currentMonth = new Date(
            currentMonth.getFullYear(),
            currentMonth.getMonth() - 1,
            1
        );
        await loadAvailability();
    });

    el('nextMonth')?.addEventListener('click', async () => {
        currentMonth = new Date(
            currentMonth.getFullYear(),
            currentMonth.getMonth() + 1,
            1
        );
        await loadAvailability();
    });

    async function loadAvailability() {
        if (isDailyRequest()) {
            availability = { days: [], details: [] };
            return;
        }

        if (studies.size === 0) {
            availability = { days: [], details: [] };
            renderCalendar();
            renderAvailabilityDetail(appointmentDateInput?.value || '');
            return;
        }

        const ids = [...studies.keys()].join(',');
        const exclude = window.excludeAppointmentId
            ? `&excludeIdCita=${encodeURIComponent(window.excludeAppointmentId)}`
            : '';

        const url =
            `?handler=Availability` +
            `&year=${currentMonth.getFullYear()}` +
            `&month=${currentMonth.getMonth() + 1}` +
            `&studies=${encodeURIComponent(ids)}` +
            exclude;

        try {
            const response = await fetch(url);
            if (!response.ok) throw new Error(`HTTP ${response.status}`);

            availability = await response.json();
        } catch (error) {
            console.error('Error al consultar disponibilidad:', error);
            availability = { days: [], details: [] };
        }

        renderCalendar();
        renderAvailabilityDetail(appointmentDateInput?.value || '');
    }

    function renderCalendar() {
        const title = el('calendarMonthTitle');
        const grid = el('calendarGrid');

        if (!title || !grid) return;

        const monthNames = [
            'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
            'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
        ];

        title.textContent =
            `${monthNames[currentMonth.getMonth()]} ${currentMonth.getFullYear()}`;

        grid.innerHTML = '';

        const first = new Date(
            currentMonth.getFullYear(),
            currentMonth.getMonth(),
            1
        );

        const daysInMonth = new Date(
            currentMonth.getFullYear(),
            currentMonth.getMonth() + 1,
            0
        ).getDate();

        const mondayOffset = (first.getDay() + 6) % 7;

        for (let i = 0; i < mondayOffset; i++) {
            const blank = document.createElement('div');
            blank.className = 'calendar-day outside';
            grid.appendChild(blank);
        }

        const selectedDate = appointmentDateInput?.value || '';

        for (let day = 1; day <= daysInMonth; day++) {
            const date = new Date(
                currentMonth.getFullYear(),
                currentMonth.getMonth(),
                day
            );

            const iso = formatLocalDate(date);

            const info = (availability.days || []).find(
                x => x.fecha?.substring(0, 10) === iso
            );

            const cell = document.createElement('button');
            cell.type = 'button';
            cell.className = `calendar-day ${statusClass(info?.estado)}`;

            if (selectedDate === iso) {
                cell.classList.add('selected');
            }

            cell.textContent = day;

            cell.addEventListener('click', () => {
                if (appointmentDateInput) {
                    appointmentDateInput.value = iso;
                }

                renderCalendar();
                renderAvailabilityDetail(iso);
            });

            grid.appendChild(cell);
        }
    }

    function renderAvailabilityDetail(isoDate) {
        const container = el('availabilityDetails');
        const message = el('availabilityMessage');

        if (!container || !message) return;

        if (!isoDate) {
            container.innerHTML =
                '<div class="text-muted py-3">Seleccione una fecha.</div>';
            return;
        }

        const date = new Date(`${isoDate}T00:00:00`);

        if (el('detailDateTitle')) {
            el('detailDateTitle').textContent =
                date.toLocaleDateString('es-GT');
        }

        if (studies.size === 0) {
            container.innerHTML =
                '<div class="text-muted py-3">Agregue estudios para calcular la disponibilidad.</div>';

            message.className = 'availability-message neutral';
            message.innerHTML =
                '<i class="bi bi-info-circle"></i><span>Seleccione los estudios y una fecha.</span>';

            return;
        }

        const details = (availability.details || []).filter(
            x => x.fecha?.substring(0, 10) === isoDate
        );

        if (details.length === 0) {
            container.innerHTML =
                '<div class="text-muted py-3">No existe información para esta fecha.</div>';

            message.className = 'availability-message warning';
            message.innerHTML =
                '<i class="bi bi-exclamation-triangle"></i><span>No existe capacidad configurada para esta fecha.</span>';

            return;
        }

        container.innerHTML = details.map(d => {
            const cap = d.capacidad ?? 0;
            const used = d.utilizados ?? 0;
            const available = d.disponibles;

            const pct = cap > 0
                ? Math.min(100, Math.round((used / cap) * 100))
                : 0;

            const text = available === null
                ? 'Sin configuración'
                : available <= 0
                    ? 'Cupo completo'
                    : `${available} disponibles`;

            return `
                <div class="availability-row">
                    <div class="availability-study">${escapeHtml(d.nombrePrueba)}</div>
                    <div class="availability-bar"><span style="width:${pct}%"></span></div>
                    <div class="availability-count">${used} / ${cap || '-'}</div>
                    <div class="availability-left ${available !== null && available <= 0 ? 'full' : ''}">
                        ${text}
                    </div>
                </div>`;
        }).join('');

        const anyNoConfig = details.some(d => d.capacidad === null);
        const anyFull = details.some(
            d => d.disponibles !== null && d.disponibles <= 0
        );

        if (anyNoConfig) {
            message.className = 'availability-message warning';
            message.innerHTML =
                '<i class="bi bi-exclamation-triangle"></i><span>Existe por lo menos un estudio sin capacidad configurada.</span>';
        } else if (anyFull) {
            message.className = 'availability-message error';
            message.innerHTML =
                '<i class="bi bi-x-circle"></i><span>No puede registrarse la solicitud: uno o más estudios no tienen cupo.</span>';
        } else {
            message.className = 'availability-message success';
            message.innerHTML =
                '<i class="bi bi-check-circle"></i><span>Hay disponibilidad para todos los estudios seleccionados.</span>';
        }
    }

    appointmentDateInput?.addEventListener('change', event => {
        const date = new Date(`${event.target.value}T00:00:00`);

        if (!Number.isNaN(date.getTime())) {
            currentMonth = new Date(
                date.getFullYear(),
                date.getMonth(),
                1
            );

            if (!isDailyRequest()) {
                loadAvailability();
            }
        }
    });

    /* =========================================================
       VALIDACIÓN ANTES DE ENVIAR
       ========================================================= */

    el('appointmentForm')?.addEventListener('submit', event => {
        const missing = [...studies.values()].find(
            study => !Array.isArray(study.partesCuerpo) ||
                     study.partesCuerpo.length === 0
        );

        if (!missing) {
            updateStudyHidden();
            return;
        }

        event.preventDefault();

        alert(
            `Debe seleccionar por lo menos una parte del cuerpo para el estudio ${missing.idPrueba}.`
        );

        openBodyPartModal(missing.idPrueba);
    });

    /* =========================================================
       UTILIDADES
       ========================================================= */

    function statusClass(status) {
        switch ((status || '').toUpperCase()) {
            case 'HIGH': return 'high';
            case 'LOW': return 'low';
            case 'FULL': return 'full';
            default: return 'none';
        }
    }

    function formatLocalDate(date) {
        const y = date.getFullYear();
        const m = String(date.getMonth() + 1).padStart(2, '0');
        const d = String(date.getDate()).padStart(2, '0');

        return `${y}-${m}-${d}`;
    }

    function safeId(value) {
        return String(value || '').replace(/[^a-zA-Z0-9_-]/g, '_');
    }

    function escapeHtml(value) {
        return String(value ?? '')
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;')
            .replaceAll("'", '&#039;');
    }

    /* =========================================================
       CARGA INICIAL
       ========================================================= */

    if (Array.isArray(window.initialStudies)) {
        window.initialStudies.forEach(rawStudy => {
            const study = normalizeStudy(rawStudy);

            if (study.idPrueba) {
                studies.set(study.idPrueba, study);
            }
        });
    }

    updateStudyHidden();
    renderStudies();
    applyRegistrationTypeUi(false);

    if (!isDailyRequest()) {
        loadAvailability();
    }

    if (btnSearchPatient && patientIdInput?.value.trim()) {
        searchPatient();
    }
})();
