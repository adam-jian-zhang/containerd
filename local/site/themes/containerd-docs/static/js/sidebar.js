// Sidebar toggle functionality
(function() {
    const menuToggle = document.getElementById('menuToggle');
    const sidebar = document.getElementById('sidebar');
    
    // Get saved state or default to expanded
    const savedState = localStorage.getItem('sidebarCollapsed') === 'true';
    if (savedState) {
        sidebar.classList.add('collapsed');
    }
    
    menuToggle.addEventListener('click', function() {
        sidebar.classList.toggle('collapsed');
        const isCollapsed = sidebar.classList.contains('collapsed');
        localStorage.setItem('sidebarCollapsed', isCollapsed);
    });
    
    // Mobile menu toggle
    if (window.innerWidth <= 768) {
        menuToggle.addEventListener('click', function() {
            sidebar.classList.toggle('mobile-open');
        });
        
        // Close sidebar when clicking outside on mobile
        document.addEventListener('click', function(event) {
            if (window.innerWidth <= 768 && 
                !sidebar.contains(event.target) && 
                !menuToggle.contains(event.target)) {
                sidebar.classList.remove('mobile-open');
            }
        });
    }
})();
