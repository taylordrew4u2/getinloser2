import { 
  fetchEvents, createEvent, updateEvent, deleteEvent,
  fetchTodos, createTodo, toggleTodoCompletion, deleteTodo,
  fetchNote, saveNote,
  fetchTickets, uploadTicket, deleteTicket,
  fetchIOUs, saveIOU, deleteIOU,
  currentUserId
} from '../services/firebase.js';
import { router } from '../main.js';

let currentTrip = null;
let currentTab = 'itinerary';

export async function renderTripDetail(container, tripId) {
  // Fetch trip data
  const { fetchTrips } = await import('../services/firebase.js');
  const trips = await fetchTrips();
  currentTrip = trips.find(t => t.id === tripId);
  
  if (!currentTrip) {
    container.innerHTML = '<div class="container"><p>Trip not found</p></div>';
    return;
  }
  
  container.innerHTML = `
    <div class="header">
      <div class="container header-content">
        <button class="btn btn-icon" id="backBtn">← Back</button>
        <h1 style="font-size: 18px; font-weight: 600;">${escapeHtml(currentTrip.name)}</h1>
        <button class="btn btn-icon" id="menuBtn">⋮</button>
      </div>
    </div>
    
    <div class="container" style="padding-top: 16px; flex: 1;">
      <div class="tabs" id="tabs">
        <button class="tab active" data-tab="itinerary">Itinerary</button>
        <button class="tab" data-tab="tickets">Tickets</button>
        <button class="tab" data-tab="notes">Notes</button>
        <button class="tab" data-tab="todos">To-Do</button>
        <button class="tab" data-tab="ious">IOUs</button>
      </div>
      
      <div id="tabContent" style="padding-top: 16px;">
        <div class="spinner"></div>
      </div>
    </div>
  `;
  
  document.getElementById('backBtn').addEventListener('click', () => router.back());
  
  // Tab switching
  document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      currentTab = tab.dataset.tab;
      renderTab(tripId);
    });
  });
  
  renderTab(tripId);
}

async function renderTab(tripId) {
  const content = document.getElementById('tabContent');
  
  switch (currentTab) {
    case 'itinerary':
      await renderItinerary(content, tripId);
      break;
    case 'tickets':
      await renderTickets(content, tripId);
      break;
    case 'notes':
      await renderNotes(content, tripId);
      break;
    case 'todos':
      await renderTodos(content, tripId);
      break;
    case 'ious':
      await renderIOUs(content, tripId);
      break;
  }
}

// ==================== ITINERARY TAB ====================

async function renderItinerary(container, tripId) {
  container.innerHTML = '<div class="spinner"></div>';
  
  const events = await fetchEvents(tripId);
  
  container.innerHTML = `
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
      <h3>Events</h3>
      <button class="btn btn-primary" id="addEventBtn">+ Add Event</button>
    </div>
    <div id="eventsList"></div>
  `;
  
  const eventsList = document.getElementById('eventsList');
  
  if (events.length === 0) {
    eventsList.innerHTML = '<div class="empty-state">No events yet. Add your first event!</div>';
  } else {
    eventsList.innerHTML = events.map(event => `
      <div class="list-item">
        <div class="list-item-header">
          <div>
            <div class="list-item-title">${escapeHtml(event.name)}</div>
            <div class="list-item-meta">
              📅 ${formatDate(event.date)} ${event.time ? `• 🕐 ${event.time}` : ''}
            </div>
            ${event.location ? `<div class="list-item-meta">📍 ${escapeHtml(event.location)}</div>` : ''}
          </div>
          <button class="btn btn-icon" data-event-id="${event.id}">🗑️</button>
        </div>
        ${event.notes ? `<p style="margin-top: 8px; color: var(--text-secondary);">${escapeHtml(event.notes)}</p>` : ''}
      </div>
    `).join('');
    
    // Delete event handlers
    eventsList.querySelectorAll('[data-event-id]').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (confirm('Delete this event?')) {
          await deleteEvent(tripId, btn.dataset.eventId);
          renderTab(tripId);
        }
      });
    });
  }
  
  document.getElementById('addEventBtn').addEventListener('click', () => showAddEventModal(tripId));
}

function showAddEventModal(tripId) {
  const modal = document.createElement('div');
  modal.className = 'modal-overlay';
  modal.innerHTML = `
    <div class="modal">
      <div class="modal-header">
        <h2 class="modal-title">Add Event</h2>
        <button class="btn btn-icon" id="closeModal">✕</button>
      </div>
      <div class="modal-body">
        <div class="form-group">
          <label class="form-label">Event Name</label>
          <input type="text" class="form-input" id="eventName" required>
        </div>
        <div class="form-group">
          <label class="form-label">Date</label>
          <input type="date" class="form-input" id="eventDate" required>
        </div>
        <div class="form-group">
          <label class="form-label">Time (optional)</label>
          <input type="time" class="form-input" id="eventTime">
        </div>
        <div class="form-group">
          <label class="form-label">Location (optional)</label>
          <input type="text" class="form-input" id="eventLocation">
        </div>
        <div class="form-group">
          <label class="form-label">Notes (optional)</label>
          <textarea class="form-input" id="eventNotes"></textarea>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" id="cancelBtn">Cancel</button>
        <button class="btn btn-primary" id="saveBtn">Add Event</button>
      </div>
    </div>
  `;
  
  document.body.appendChild(modal);
  const closeModal = () => modal.remove();
  
  document.getElementById('closeModal').addEventListener('click', closeModal);
  document.getElementById('cancelBtn').addEventListener('click', closeModal);
  
  document.getElementById('saveBtn').addEventListener('click', async () => {
    const name = document.getElementById('eventName').value;
    const date = new Date(document.getElementById('eventDate').value);
    const time = document.getElementById('eventTime').value;
    const location = document.getElementById('eventLocation').value;
    const notes = document.getElementById('eventNotes').value;
    
    if (!name || !date) return;
    
    await createEvent(tripId, { name, date, time, location, notes });
    closeModal();
    renderTab(tripId);
  });
}

// ==================== TICKETS TAB ====================

async function renderTickets(container, tripId) {
  container.innerHTML = '<div class="spinner"></div>';
  
  const tickets = await fetchTickets(tripId);
  
  container.innerHTML = `
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
      <h3>Tickets & Documents</h3>
      <label class="btn btn-primary" for="uploadFile">+ Upload</label>
      <input type="file" id="uploadFile" style="display: none;" accept="image/*,.pdf">
    </div>
    <div id="ticketsList"></div>
  `;
  
  const ticketsList = document.getElementById('ticketsList');
  
  if (tickets.length === 0) {
    ticketsList.innerHTML = '<div class="empty-state">No tickets yet. Upload your first document!</div>';
  } else {
    ticketsList.innerHTML = tickets.map(ticket => `
      <div class="list-item">
        <div class="list-item-header">
          <div>
            <div class="list-item-title">📄 ${escapeHtml(ticket.fileName)}</div>
            <div class="list-item-meta">${formatDate(ticket.uploadDate)}</div>
          </div>
          <div style="display: flex; gap: 8px;">
            <a href="${ticket.fileURL}" target="_blank" class="btn btn-secondary">View</a>
            <button class="btn btn-icon" data-ticket-id="${ticket.id}">🗑️</button>
          </div>
        </div>
      </div>
    `).join('');
    
    ticketsList.querySelectorAll('[data-ticket-id]').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (confirm('Delete this ticket?')) {
          const ticket = tickets.find(t => t.id === btn.dataset.ticketId);
          await deleteTicket(tripId, ticket);
          renderTab(tripId);
        }
      });
    });
  }
  
  document.getElementById('uploadFile').addEventListener('change', async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    
    ticketsList.innerHTML = '<div class="spinner"></div><p class="text-center">Uploading...</p>';
    
    try {
      await uploadTicket(tripId, file);
      renderTab(tripId);
    } catch (error) {
      alert('Upload failed: ' + error.message);
      renderTab(tripId);
    }
  });
}

// ==================== NOTES TAB ====================

async function renderNotes(container, tripId) {
  container.innerHTML = '<div class="spinner"></div>';
  
  const note = await fetchNote(tripId);
  
  container.innerHTML = `
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
      <h3>Shared Notes</h3>
      <button class="btn btn-primary" id="saveNoteBtn">Save</button>
    </div>
    <textarea class="form-input" id="noteContent" placeholder="Write your trip notes here..." style="min-height: 300px;">${note?.content || ''}</textarea>
    <div id="saveStatus" class="success-message hidden" style="margin-top: 8px;">Notes saved!</div>
  `;
  
  let saveTimeout;
  const textarea = document.getElementById('noteContent');
  const saveStatus = document.getElementById('saveStatus');
  
  const doSave = async () => {
    await saveNote(tripId, textarea.value);
    saveStatus.classList.remove('hidden');
    setTimeout(() => saveStatus.classList.add('hidden'), 2000);
  };
  
  // Auto-save after 2 seconds of no typing
  textarea.addEventListener('input', () => {
    clearTimeout(saveTimeout);
    saveTimeout = setTimeout(doSave, 2000);
  });
  
  document.getElementById('saveNoteBtn').addEventListener('click', doSave);
}

// ==================== TODOS TAB ====================

async function renderTodos(container, tripId) {
  container.innerHTML = '<div class="spinner"></div>';
  
  const todos = await fetchTodos(tripId);
  
  container.innerHTML = `
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
      <h3>To-Do List</h3>
      <button class="btn btn-primary" id="addTodoBtn">+ Add To-Do</button>
    </div>
    <div id="todosList"></div>
  `;
  
  const todosList = document.getElementById('todosList');
  
  if (todos.length === 0) {
    todosList.innerHTML = '<div class="empty-state">No to-dos yet. Add your first task!</div>';
  } else {
    todosList.innerHTML = todos.map(todo => {
      const isCompleted = todo.completedBy?.[currentUserId] || false;
      return `
        <div class="list-item">
          <div class="list-item-header">
            <div style="display: flex; align-items: center; gap: 12px;">
              <input type="checkbox" ${isCompleted ? 'checked' : ''} data-todo-id="${todo.id}" style="width: 20px; height: 20px; cursor: pointer;">
              <div class="list-item-title" style="${isCompleted ? 'text-decoration: line-through; color: var(--text-secondary);' : ''}">${escapeHtml(todo.title)}</div>
            </div>
            <button class="btn btn-icon" data-delete-todo="${todo.id}">🗑️</button>
          </div>
        </div>
      `;
    }).join('');
    
    todosList.querySelectorAll('input[type="checkbox"]').forEach(checkbox => {
      checkbox.addEventListener('change', async () => {
        const todo = todos.find(t => t.id === checkbox.dataset.todoId);
        await toggleTodoCompletion(tripId, todo);
        renderTab(tripId);
      });
    });
    
    todosList.querySelectorAll('[data-delete-todo]').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (confirm('Delete this to-do?')) {
          await deleteTodo(tripId, btn.dataset.deleteTodo);
          renderTab(tripId);
        }
      });
    });
  }
  
  document.getElementById('addTodoBtn').addEventListener('click', () => showAddTodoModal(tripId));
}

function showAddTodoModal(tripId) {
  const modal = document.createElement('div');
  modal.className = 'modal-overlay';
  modal.innerHTML = `
    <div class="modal">
      <div class="modal-header">
        <h2 class="modal-title">Add To-Do</h2>
        <button class="btn btn-icon" id="closeModal">✕</button>
      </div>
      <div class="modal-body">
        <div class="form-group">
          <label class="form-label">Task</label>
          <input type="text" class="form-input" id="todoTitle" required>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" id="cancelBtn">Cancel</button>
        <button class="btn btn-primary" id="saveBtn">Add</button>
      </div>
    </div>
  `;
  
  document.body.appendChild(modal);
  const closeModal = () => modal.remove();
  
  document.getElementById('closeModal').addEventListener('click', closeModal);
  document.getElementById('cancelBtn').addEventListener('click', closeModal);
  
  document.getElementById('saveBtn').addEventListener('click', async () => {
    const title = document.getElementById('todoTitle').value;
    if (!title) return;
    
    await createTodo(tripId, { title });
    closeModal();
    renderTab(tripId);
  });
}

// ==================== IOUs TAB ====================

async function renderIOUs(container, tripId) {
  container.innerHTML = '<div class="spinner"></div>';
  
  const ious = await fetchIOUs(tripId);
  
  container.innerHTML = `
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
      <h3>IOUs</h3>
      <button class="btn btn-primary" id="addIOUBtn">+ Add IOU</button>
    </div>
    <div id="iousList"></div>
  `;
  
  const iousList = document.getElementById('iousList');
  
  if (ious.length === 0) {
    iousList.innerHTML = '<div class="empty-state">No IOUs yet. Track who owes what!</div>';
  } else {
    iousList.innerHTML = ious.map(iou => `
      <div class="list-item">
        <div class="list-item-header">
          <div>
            <div class="list-item-title">${escapeHtml(iou.fromName)} owes ${escapeHtml(iou.toName)}</div>
            <div class="list-item-meta">$${iou.amount.toFixed(2)} • ${escapeHtml(iou.description)}</div>
          </div>
          <button class="btn btn-icon" data-iou-id="${iou.id}">🗑️</button>
        </div>
      </div>
    `).join('');
    
    iousList.querySelectorAll('[data-iou-id]').forEach(btn => {
      btn.addEventListener('click', async () => {
        if (confirm('Delete this IOU?')) {
          await deleteIOU(tripId, btn.dataset.iouId);
          renderTab(tripId);
        }
      });
    });
  }
  
  document.getElementById('addIOUBtn').addEventListener('click', () => showAddIOUModal(tripId));
}

function showAddIOUModal(tripId) {
  const modal = document.createElement('div');
  modal.className = 'modal-overlay';
  modal.innerHTML = `
    <div class="modal">
      <div class="modal-header">
        <h2 class="modal-title">Add IOU</h2>
        <button class="btn btn-icon" id="closeModal">✕</button>
      </div>
      <div class="modal-body">
        <div class="form-group">
          <label class="form-label">From</label>
          <input type="text" class="form-input" id="fromName" required>
        </div>
        <div class="form-group">
          <label class="form-label">To</label>
          <input type="text" class="form-input" id="toName" required>
        </div>
        <div class="form-group">
          <label class="form-label">Amount</label>
          <input type="number" class="form-input" id="amount" required step="0.01" min="0">
        </div>
        <div class="form-group">
          <label class="form-label">Description</label>
          <input type="text" class="form-input" id="description" required>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-secondary" id="cancelBtn">Cancel</button>
        <button class="btn btn-primary" id="saveBtn">Add</button>
      </div>
    </div>
  `;
  
  document.body.appendChild(modal);
  const closeModal = () => modal.remove();
  
  document.getElementById('closeModal').addEventListener('click', closeModal);
  document.getElementById('cancelBtn').addEventListener('click', closeModal);
  
  document.getElementById('saveBtn').addEventListener('click', async () => {
    const fromName = document.getElementById('fromName').value;
    const toName = document.getElementById('toName').value;
    const amount = parseFloat(document.getElementById('amount').value);
    const description = document.getElementById('description').value;
    
    if (!fromName || !toName || !amount || !description) return;
    
    await saveIOU(tripId, { fromName, toName, amount, description });
    closeModal();
    renderTab(tripId);
  });
}

// Helper functions
function formatDate(date) {
  if (!date) return '';
  return new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
