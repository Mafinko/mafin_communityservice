const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mafin_communityservice';
const body = document.body;
const tabs = document.querySelectorAll('.tab');
const modeLabel = document.querySelector('#mode-label');
const formTitle = document.querySelector('#form-title');
const serviceHud = document.querySelector('#service-hud');
const hudReason = document.querySelector('#hud-reason');
const hudActions = document.querySelector('#hud-actions');
const logsList = document.querySelector('#logs-list');
const views = {
	assign: document.querySelector('#assign-form'),
	release: document.querySelector('#release-form'),
	logs: document.querySelector('#logs-view')
};

['copy', 'cut', 'contextmenu', 'dragstart', 'selectstart'].forEach((eventName) => {
	document.addEventListener(eventName, (event) => {
		event.preventDefault();
	});
});

document.addEventListener('keydown', (event) => {
	if ((event.ctrlKey || event.metaKey) && ['a', 'c', 'x'].includes(event.key.toLowerCase())) {
		event.preventDefault();
	}
});

function post(name, data = {}) {
	return fetch(`https://${resource}/${name}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify(data)
	});
}

function setTab(name) {
	const activeName = ['assign', 'release', 'logs'].includes(name) ? name : 'assign';

	tabs.forEach((tab) => tab.classList.toggle('active', tab.dataset.tab === activeName));
	Object.entries(views).forEach(([viewName, element]) => {
		element.classList.toggle('active', viewName === activeName);
	});

	modeLabel.textContent = activeName.charAt(0).toUpperCase() + activeName.slice(1);

	if (activeName === 'release') {
		formTitle.textContent = 'RELEASE PLAYER';
	} else if (activeName === 'logs') {
		formTitle.textContent = 'COMMUNITY SERVICE LOGS';
		refreshLogs();
	} else {
		formTitle.textContent = 'ASSIGN COMMUNITY SERVICE';
	}
}

function closePanel() {
	body.classList.remove('open');
	post('close');
}

function updateServiceHud(data) {
	const visible = Boolean(data.visible);
	serviceHud.classList.toggle('visible', visible);

	if (!visible) return;

	const actions = Number(data.actions || 0);
	hudReason.textContent = data.reason || 'No reason provided';
	hudActions.textContent = `${actions} action${actions === 1 ? '' : 's'} remaining`;
}

function escapeHtml(value) {
	return String(value == null ? '' : value).replace(/[&<>"']/g, (character) => {
		return {
			'&': '&amp;',
			'<': '&lt;',
			'>': '&gt;',
			'"': '&quot;',
			"'": '&#039;'
		}[character];
	});
}

function renderLogs(logs) {
	logsList.innerHTML = '';

	if (!logs || logs.length === 0) {
		logsList.innerHTML = '<div class="empty-log">No logs yet.</div>';
		return;
	}

	logs.forEach((log) => {
		const item = document.createElement('article');
		item.className = 'log-entry';

		const fields = (log.fields || []).slice(0, 3).map((field) => {
			return `<span>${escapeHtml(field.name)}: <strong>${escapeHtml(field.value)}</strong></span>`;
		}).join('');

		item.innerHTML = `
			<div class="log-head">
				<strong>${escapeHtml(log.title || 'Community Service Log')}</strong>
				<time>${escapeHtml(log.time || '--:--:--')}</time>
			</div>
			<p>${escapeHtml(log.category || 'community_service')}</p>
			<div class="log-fields">${fields}</div>
		`;

		logsList.appendChild(item);
	});
}

function refreshLogs() {
	post('getLogs')
		.then((response) => response.json())
		.then((data) => renderLogs(data.logs || []))
		.catch(() => renderLogs([]));
}

window.addEventListener('message', (event) => {
	if (!event.data) return;

	if (event.data.action === 'serviceStatus') {
		updateServiceHud(event.data);
		return;
	}

	if (event.data.action === 'close') {
		body.classList.remove('open');
		return;
	}

	if (event.data.action !== 'open') return;

	body.classList.add('open');
	setTab(event.data.mode);

	if (event.data.maxActions) {
		document.querySelector('#assign-actions').max = event.data.maxActions;
	}

	if (event.data.maxReasonLength) {
		document.querySelector('#assign-reason').maxLength = event.data.maxReasonLength;
		document.querySelector('#release-reason').maxLength = event.data.maxReasonLength;
	}
});

tabs.forEach((tab) => {
	tab.addEventListener('click', () => setTab(tab.dataset.tab));
});

document.querySelector('#close').addEventListener('click', closePanel);

document.addEventListener('keydown', (event) => {
	if (event.key === 'Escape') {
		closePanel();
	}
});

views.assign.addEventListener('submit', (event) => {
	event.preventDefault();
	body.classList.remove('open');
	post('assignService', {
		target: document.querySelector('#assign-target').value,
		actions: document.querySelector('#assign-actions').value,
		reason: document.querySelector('#assign-reason').value
	});
	views.assign.reset();
});

views.release.addEventListener('submit', (event) => {
	event.preventDefault();
	body.classList.remove('open');
	post('releaseService', {
		target: document.querySelector('#release-target').value,
		reason: document.querySelector('#release-reason').value
	});
	views.release.reset();
});
