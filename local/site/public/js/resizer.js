// Resizable sidebar functionality
(function() {
    const resizer = document.querySelector('.resizer');
    const sidebar = document.getElementById('sidebar');
    const content = document.querySelector('.content');
    
    let isResizing = false;
    let startX = 0;
    let startWidth = 0;
    
    // Get saved width or use default
    const savedWidth = localStorage.getItem('sidebarWidth');
    if (savedWidth && !sidebar.classList.contains('collapsed')) {
        const width = parseInt(savedWidth);
        sidebar.style.width = width + 'px';
        content.style.marginLeft = width + 'px';
        resizer.style.left = width + 'px';
    }
    
    resizer.addEventListener('mousedown', function(e) {
        if (sidebar.classList.contains('collapsed')) {
            return;
        }
        
        isResizing = true;
        startX = e.clientX;
        startWidth = sidebar.offsetWidth;
        
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
        
        e.preventDefault();
    });
    
    document.addEventListener('mousemove', function(e) {
        if (!isResizing) return;
        
        const diff = e.clientX - startX;
        const newWidth = startWidth + diff;
        
        // Constrain width between min and max
        const minWidth = 200;
        const maxWidth = 400;
        const constrainedWidth = Math.max(minWidth, Math.min(maxWidth, newWidth));
        
        sidebar.style.width = constrainedWidth + 'px';
        content.style.marginLeft = constrainedWidth + 'px';
        resizer.style.left = constrainedWidth + 'px';
    });
    
    document.addEventListener('mouseup', function() {
        if (isResizing) {
            isResizing = false;
            document.body.style.cursor = '';
            document.body.style.userSelect = '';
            
            // Save the width
            const width = sidebar.offsetWidth;
            localStorage.setItem('sidebarWidth', width);
        }
    });
    
    // Update resizer position when sidebar is collapsed/expanded
    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            if (mutation.attributeName === 'class') {
                if (sidebar.classList.contains('collapsed')) {
                    resizer.style.left = '60px';
                } else {
                    const width = sidebar.offsetWidth;
                    resizer.style.left = width + 'px';
                }
            }
        });
    });
    
    observer.observe(sidebar, { attributes: true });
})();
