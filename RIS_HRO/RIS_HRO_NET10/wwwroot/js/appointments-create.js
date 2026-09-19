(() => {
    const studies = new Map();
    let currentMonth = new Date();
    currentMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1);
    let availability = { days: [], details: [] };
    const el = id => document.getElementById(id);

    async function searchPatient() {
        const id = el('patientId').value.trim();
        el('patientMessage').textContent = '';
        el('patientSummary').classList.add('d-none');
        el('manualPatientSection').classList.add('d-none');

        if (!id) {
            el('patientMessage').textContent = 'Ingrese el ID del paciente.';
            return;
        }

        el('patientMessage').textContent = 'Consultando paciente...';
        const response = await fetch(`?handler=Patient&id=${encodeURIComponent(id)}`);
        const data = await response.json();
        el('patientMessage').textContent = data.message || '';

        if (data.found && data.patient) {
            const p = data.patient;
            el('patientFirstName').value = p.primerNombre || '';
            el('patientSecondName').value = p.segundoNombre || '';
            el('patientFirstLastName').value = p.primerApellido || '';
            el('patientSecondLastName').value = p.segundoApellido || '';
            el('patientBirthDate').value = p.fechaNacimiento ? p.fechaNacimiento.substring(0, 10) : '';
            el('patientSex').value = p.sexo || '';
            if (el('patientPhone')) el('patientPhone').value = p.telefono || '';
            el('patientSummaryName').textContent =
                p.nombreCompleto || [p.primerNombre, p.segundoNombre, p.primerApellido, p.segundoApellido].filter(Boolean).join(' ');
            el('patientSummarySource').textContent =
                data.source === 'HOSPITAL'
                    ? 'Información obtenida del sistema institucional.'
                    : 'Información obtenida de la base local.';
            el('patientSummary').classList.remove('d-none');
        } else {
            el('manualPatientSection').classList.remove('d-none');
        }
    }

    el('btnSearchPatient').addEventListener('click', searchPatient);
    el('patientId').addEventListener('keydown', e => {
        if (e.key === 'Enter') { e.preventDefault(); searchPatient(); }
    });

    function updateStudyHidden() {
        el('studyIdsCsv').value = [...studies.keys()].join(',');
    }

    function renderStudies() {
        const body = el('studiesBody');
        body.innerHTML = '';

        if (studies.size === 0) {
            body.innerHTML = '<tr><td colspan="5" class="text-center text-muted py-4">Agregue por lo menos un estudio.</td></tr>';
        } else {
            for (const study of studies.values()) {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td><strong>${escapeHtml(study.idPrueba)}</strong></td>
                    <td>${escapeHtml(study.nombrePrueba)}</td>
                    <td>${escapeHtml(study.nombreCategoria)}</td>
                    <td class="text-muted">Pendiente asignar</td>
                    <td><button type="button" class="study-remove" data-code="${escapeHtml(study.idPrueba)}"><i class="bi bi-trash"></i> Eliminar</button></td>`;
                body.appendChild(row);
            }
        }

        body.querySelectorAll('.study-remove').forEach(btn => {
            btn.addEventListener('click', () => {
                studies.delete(btn.dataset.code);
                updateStudyHidden();
                renderStudies();
                loadAvailability();
            });
        });

        updateStudyHidden();
    }

    async function addStudyByCode(code) {
        code = (code || '').trim().toUpperCase();
        if (!code) return;
        if (studies.has(code)) { el('studyCode').value = ''; return; }

        const response = await fetch(`?handler=Study&code=${encodeURIComponent(code)}`);
        const data = await response.json();

        if (!data.found || !data.study) {
            alert('No se encontró un estudio activo con ese código.');
            return;
        }

        studies.set(data.study.idPrueba, data.study);
        el('studyCode').value = '';
        renderStudies();
        await loadAvailability();
    }

    el('btnAddStudyCode').addEventListener('click', () => addStudyByCode(el('studyCode').value));
    el('studyCode').addEventListener('keydown', e => {
        if (e.key === 'Enter') { e.preventDefault(); addStudyByCode(e.currentTarget.value); }
    });

    async function searchStudies() {
        const q = el('studySearchText').value.trim();
        const response = await fetch(`?handler=Studies&q=${encodeURIComponent(q)}`);
        const data = await response.json();
        const body = el('studySearchBody');
        body.innerHTML = '';

        data.forEach(study => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td><strong>${escapeHtml(study.idPrueba)}</strong></td>
                <td>${escapeHtml(study.nombrePrueba)}</td>
                <td>${escapeHtml(study.nombreCategoria)}</td>
                <td class="text-end"><button type="button" class="btn-ris-small">Agregar</button></td>`;
            row.querySelector('button').addEventListener('click', async () => {
                studies.set(study.idPrueba, study);
                renderStudies();
                await loadAvailability();
            });
            body.appendChild(row);
        });
    }

    el('studySearchText').addEventListener('input', searchStudies);
    document.getElementById('studyModal').addEventListener('shown.bs.modal', searchStudies);

    el('prevMonth').addEventListener('click', async () => {
        currentMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth() - 1, 1);
        await loadAvailability();
    });

    el('nextMonth').addEventListener('click', async () => {
        currentMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 1);
        await loadAvailability();
    });

    async function loadAvailability() {
        if (studies.size === 0) {
            availability = { days: [], details: [] };
            renderCalendar();
            renderAvailabilityDetail(el('appointmentDate').value);
            return;
        }

        const ids = [...studies.keys()].join(',');
        const url = `?handler=Availability&year=${currentMonth.getFullYear()}&month=${currentMonth.getMonth()+1}&studies=${encodeURIComponent(ids)}`;
        const response = await fetch(url);
        availability = await response.json();
        renderCalendar();
        renderAvailabilityDetail(el('appointmentDate').value);
    }

    function renderCalendar() {
        const monthNames = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
        el('calendarMonthTitle').textContent = `${monthNames[currentMonth.getMonth()]} ${currentMonth.getFullYear()}`;
        const grid = el('calendarGrid');
        grid.innerHTML = '';

        const first = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1);
        const daysInMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth()+1, 0).getDate();
        const mondayOffset = (first.getDay() + 6) % 7;

        for (let i = 0; i < mondayOffset; i++) {
            const blank = document.createElement('div');
            blank.className = 'calendar-day outside';
            grid.appendChild(blank);
        }

        const selectedDate = el('appointmentDate').value;

        for (let day = 1; day <= daysInMonth; day++) {
            const date = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), day);
            const iso = formatLocalDate(date);
            const info = (availability.days || []).find(x => x.fecha.substring(0,10) === iso);
            const cell = document.createElement('button');
            cell.type = 'button';
            cell.className = `calendar-day ${statusClass(info?.estado)}`;
            if (selectedDate === iso) cell.classList.add('selected');
            cell.textContent = day;
            cell.addEventListener('click', () => {
                el('appointmentDate').value = iso;
                renderCalendar();
                renderAvailabilityDetail(iso);
            });
            grid.appendChild(cell);
        }
    }

    function renderAvailabilityDetail(isoDate) {
        const container = el('availabilityDetails');
        const message = el('availabilityMessage');

        if (!isoDate) {
            container.innerHTML = '<div class="text-muted py-3">Seleccione una fecha.</div>';
            return;
        }

        const date = new Date(`${isoDate}T00:00:00`);
        el('detailDateTitle').textContent = date.toLocaleDateString('es-GT');

        if (studies.size === 0) {
            container.innerHTML = '<div class="text-muted py-3">Agregue estudios para calcular la disponibilidad.</div>';
            message.className = 'availability-message neutral';
            message.innerHTML = '<i class="bi bi-info-circle"></i><span>Seleccione los estudios y una fecha.</span>';
            return;
        }

        const details = (availability.details || []).filter(x => x.fecha.substring(0,10) === isoDate);

        if (details.length === 0) {
            container.innerHTML = '<div class="text-muted py-3">No existe información para esta fecha.</div>';
            message.className = 'availability-message warning';
            message.innerHTML = '<i class="bi bi-exclamation-triangle"></i><span>No existe capacidad configurada para esta fecha.</span>';
            return;
        }

        container.innerHTML = details.map(d => {
            const cap = d.capacidad ?? 0;
            const used = d.utilizados ?? 0;
            const available = d.disponibles;
            const pct = cap > 0 ? Math.min(100, Math.round((used / cap) * 100)) : 0;
            const text = available === null ? 'Sin configuración' :
                         available <= 0 ? 'Cupo completo' : `${available} disponibles`;

            return `
                <div class="availability-row">
                    <div class="availability-study">${escapeHtml(d.nombrePrueba)}</div>
                    <div class="availability-bar"><span style="width:${pct}%"></span></div>
                    <div class="availability-count">${used} / ${cap || '-'}</div>
                    <div class="availability-left ${available !== null && available <= 0 ? 'full' : ''}">${text}</div>
                </div>`;
        }).join('');

        const anyNoConfig = details.some(d => d.capacidad === null);
        const anyFull = details.some(d => d.disponibles !== null && d.disponibles <= 0);

        if (anyNoConfig) {
            message.className = 'availability-message warning';
            message.innerHTML = '<i class="bi bi-exclamation-triangle"></i><span>Existe por lo menos un estudio sin capacidad configurada.</span>';
        } else if (anyFull) {
            message.className = 'availability-message error';
            message.innerHTML = '<i class="bi bi-x-circle"></i><span>No puede registrarse la cita: uno o más estudios no tienen cupo.</span>';
        } else {
            message.className = 'availability-message success';
            message.innerHTML = '<i class="bi bi-check-circle"></i><span>La cita puede registrarse. Hay disponibilidad para todos los estudios seleccionados.</span>';
        }
    }

    el('appointmentDate').addEventListener('change', e => {
        const date = new Date(`${e.target.value}T00:00:00`);
        if (!isNaN(date)) {
            currentMonth = new Date(date.getFullYear(), date.getMonth(), 1);
            loadAvailability();
        }
    });

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
        const m = String(date.getMonth()+1).padStart(2,'0');
        const d = String(date.getDate()).padStart(2,'0');
        return `${y}-${m}-${d}`;
    }

    function escapeHtml(value) {
        return String(value ?? '')
            .replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;')
            .replaceAll('"','&quot;').replaceAll("'",'&#039;');
    }

    if (Array.isArray(window.initialStudies)) {
        window.initialStudies.forEach(study => studies.set(study.idPrueba, study));
    }
    renderStudies();
    loadAvailability();

    if (patientId && patientId.value.trim()) {
        searchPatient();
    }
})();
