import { initializeApp } from 'firebase/app';
import { getFirestore, collection, query, where, orderBy, getDocs, doc, setDoc, updateDoc, deleteDoc, getDoc } from 'firebase/firestore';
import { getStorage, ref, uploadBytes, getDownloadURL, deleteObject } from 'firebase/storage';
import { firebaseConfig } from '../config/firebase-config.js';

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const storage = getStorage(app);

// Get or generate user ID
function getUserId() {
  let userId = localStorage.getItem('userId');
  if (!userId) {
    userId = 'user_' + Math.random().toString(36).substr(2, 9) + Date.now();
    localStorage.setItem('userId', userId);
  }
  return userId;
}

export const currentUserId = getUserId();

// ==================== TRIPS ====================

export async function fetchTrips() {
  try {
    const q = query(
      collection(db, 'trips'),
      where('memberIDs', 'array-contains', currentUserId),
      orderBy('startDate', 'desc')
    );
    
    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      startDate: doc.data().startDate?.toDate(),
      endDate: doc.data().endDate?.toDate()
    }));
  } catch (error) {
    console.error('Error fetching trips:', error);
    return [];
  }
}

export async function createTrip(tripData) {
  const tripId = 'trip_' + Date.now() + Math.random().toString(36).substr(2, 9);
  
  const trip = {
    ...tripData,
    id: tripId,
    memberIDs: [currentUserId, ...(tripData.memberIDs || [])],
    ownerID: currentUserId,
    inviteCode: generateInviteCode(),
    createdAt: new Date()
  };
  
  await setDoc(doc(db, 'trips', tripId), trip);
  return { ...trip, startDate: trip.startDate, endDate: trip.endDate };
}

export async function updateTrip(tripId, updates) {
  await updateDoc(doc(db, 'trips', tripId), updates);
}

export async function deleteTrip(tripId) {
  await deleteDoc(doc(db, 'trips', tripId));
}

export async function findTripByInviteCode(code) {
  const normalizedCode = code.toUpperCase().trim();
  const q = query(
    collection(db, 'trips'),
    where('inviteCode', '==', normalizedCode)
  );
  
  const snapshot = await getDocs(q);
  if (snapshot.empty) return null;
  
  const doc = snapshot.docs[0];
  return {
    id: doc.id,
    ...doc.data(),
    startDate: doc.data().startDate?.toDate(),
    endDate: doc.data().endDate?.toDate()
  };
}

export async function joinTrip(code) {
  const trip = await findTripByInviteCode(code);
  if (!trip) {
    throw new Error('Invalid invite code');
  }
  
  if (trip.memberIDs.includes(currentUserId)) {
    throw new Error('You are already a member of this trip');
  }
  
  await updateDoc(doc(db, 'trips', trip.id), {
    memberIDs: [...trip.memberIDs, currentUserId]
  });
  
  return trip;
}

function generateInviteCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return Array.from({ length: 6 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
}

// ==================== EVENTS ====================

export async function fetchEvents(tripId) {
  try {
    const snapshot = await getDocs(
      collection(db, 'trips', tripId, 'events')
    );
    
    const events = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      date: doc.data().date?.toDate(),
      time: doc.data().time
    }));
    
    return events.sort((a, b) => {
      const dateCompare = a.date - b.date;
      if (dateCompare !== 0) return dateCompare;
      return (a.time || '').localeCompare(b.time || '');
    });
  } catch (error) {
    console.error('Error fetching events:', error);
    return [];
  }
}

export async function createEvent(tripId, eventData) {
  const eventId = 'event_' + Date.now() + Math.random().toString(36).substr(2, 9);
  
  const event = {
    ...eventData,
    id: eventId,
    tripID: tripId,
    createdAt: new Date()
  };
  
  await setDoc(doc(db, 'trips', tripId, 'events', eventId), event);
  return event;
}

export async function updateEvent(tripId, eventId, updates) {
  await updateDoc(doc(db, 'trips', tripId, 'events', eventId), updates);
}

export async function deleteEvent(tripId, eventId) {
  await deleteDoc(doc(db, 'trips', tripId, 'events', eventId));
}

// ==================== TODOS ====================

export async function fetchTodos(tripId) {
  try {
    const snapshot = await getDocs(
      collection(db, 'trips', tripId, 'todos')
    );
    
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
  } catch (error) {
    console.error('Error fetching todos:', error);
    return [];
  }
}

export async function createTodo(tripId, todoData) {
  const todoId = 'todo_' + Date.now() + Math.random().toString(36).substr(2, 9);
  
  const todo = {
    ...todoData,
    id: todoId,
    tripID: tripId,
    completedBy: {},
    createdAt: new Date()
  };
  
  await setDoc(doc(db, 'trips', tripId, 'todos', todoId), todo);
  return todo;
}

export async function updateTodo(tripId, todoId, updates) {
  await updateDoc(doc(db, 'trips', tripId, 'todos', todoId), updates);
}

export async function toggleTodoCompletion(tripId, todo) {
  const completedBy = { ...todo.completedBy };
  completedBy[currentUserId] = !completedBy[currentUserId];
  
  await updateDoc(doc(db, 'trips', tripId, 'todos', todo.id), {
    completedBy
  });
}

export async function deleteTodo(tripId, todoId) {
  await deleteDoc(doc(db, 'trips', tripId, 'todos', todoId));
}

// ==================== NOTES ====================

export async function fetchNote(tripId) {
  try {
    const snapshot = await getDocs(
      collection(db, 'trips', tripId, 'notes')
    );
    
    if (snapshot.empty) return null;
    
    const doc = snapshot.docs[0];
    return {
      id: doc.id,
      ...doc.data()
    };
  } catch (error) {
    console.error('Error fetching note:', error);
    return null;
  }
}

export async function saveNote(tripId, content) {
  const noteId = 'note_' + tripId;
  
  const note = {
    id: noteId,
    tripID: tripId,
    content,
    lastModified: new Date()
  };
  
  await setDoc(doc(db, 'trips', tripId, 'notes', noteId), note);
  return note;
}

// ==================== TICKETS ====================

export async function fetchTickets(tripId) {
  try {
    const snapshot = await getDocs(
      collection(db, 'trips', tripId, 'tickets')
    );
    
    const tickets = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      uploadDate: doc.data().uploadDate?.toDate()
    }));
    
    return tickets.sort((a, b) => b.uploadDate - a.uploadDate);
  } catch (error) {
    console.error('Error fetching tickets:', error);
    return [];
  }
}

export async function uploadTicket(tripId, file) {
  const ticketId = 'ticket_' + Date.now() + Math.random().toString(36).substr(2, 9);
  const fileName = file.name;
  const storageRef = ref(storage, `tickets/${tripId}/${ticketId}_${fileName}`);
  
  // Upload file
  await uploadBytes(storageRef, file);
  
  // Get download URL
  const fileURL = await getDownloadURL(storageRef);
  
  // Save metadata to Firestore
  const ticket = {
    id: ticketId,
    tripID: tripId,
    fileName,
    fileType: file.type,
    fileURL,
    uploadDate: new Date(),
    uploadedBy: currentUserId
  };
  
  await setDoc(doc(db, 'trips', tripId, 'tickets', ticketId), ticket);
  return ticket;
}

export async function deleteTicket(tripId, ticket) {
  // Delete from Storage
  if (ticket.fileURL) {
    try {
      const storageRef = ref(storage, ticket.fileURL);
      await deleteObject(storageRef);
    } catch (error) {
      console.error('Error deleting file:', error);
    }
  }
  
  // Delete from Firestore
  await deleteDoc(doc(db, 'trips', tripId, 'tickets', ticket.id));
}

// ==================== IOUs ====================

export async function fetchIOUs(tripId) {
  try {
    const snapshot = await getDocs(
      collection(db, 'trips', tripId, 'iou')
    );
    
    const ious = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      lastModifiedDate: doc.data().lastModifiedDate?.toDate()
    }));
    
    return ious.sort((a, b) => b.lastModifiedDate - a.lastModifiedDate);
  } catch (error) {
    console.error('Error fetching IOUs:', error);
    return [];
  }
}

export async function saveIOU(tripId, iouData) {
  const iouId = iouData.id || 'iou_' + Date.now() + Math.random().toString(36).substr(2, 9);
  
  const iou = {
    ...iouData,
    id: iouId,
    tripID: tripId,
    lastModifiedDate: new Date()
  };
  
  await setDoc(doc(db, 'trips', tripId, 'iou', iouId), iou);
  return iou;
}

export async function deleteIOU(tripId, iouId) {
  await deleteDoc(doc(db, 'trips', tripId, 'iou', iouId));
}

// ==================== MEMBERS ====================

export async function fetchMembers(memberIDs) {
  if (!memberIDs || memberIDs.length === 0) return [];
  
  try {
    const snapshot = await getDocs(
      query(
        collection(db, 'members'),
        where('userRecordID', 'in', memberIDs.slice(0, 10)) // Firestore limit
      )
    );
    
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
  } catch (error) {
    console.error('Error fetching members:', error);
    return [];
  }
}
