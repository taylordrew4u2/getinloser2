import './styles.css';
import { renderHome } from './views/home.js';
import { renderTripDetail } from './views/trip-detail.js';

// Simple router
class Router {
  constructor() {
    this.routes = {};
    this.currentRoute = null;
    
    window.addEventListener('popstate', () => this.handleRoute());
  }
  
  register(path, handler) {
    this.routes[path] = handler;
  }
  
  navigate(path, data = {}) {
    window.history.pushState(data, '', path);
    this.handleRoute();
  }
  
  back() {
    window.history.back();
  }
  
  handleRoute() {
    const path = window.location.pathname;
    const state = window.history.state || {};
    
    // Match routes
    if (path === '/' || path === '/index.html') {
      this.routes['home']?.(state);
    } else if (path.startsWith('/trip/')) {
      const tripId = path.split('/')[2];
      this.routes['trip']?.({ ...state, tripId });
    } else {
      this.routes['home']?.(state);
    }
  }
}

export const router = new Router();

// Initialize app
function init() {
  const app = document.getElementById('app');
  
  // Register routes
  router.register('home', () => {
    renderHome(app);
  });
  
  router.register('trip', ({ tripId }) => {
    renderTripDetail(app, tripId);
  });
  
  // Handle initial route
  router.handleRoute();
}

// Start app when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
