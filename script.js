document.addEventListener('DOMContentLoaded', () => {
    const preregForm = document.getElementById('prereg-form');
    const responseMessage = document.getElementById('response-message');
    const supabaseUrl = 'https://rrbsjmfwahaerkfhpegv.supabase.co';
    // IMPORTANT: Replace with your actual Supabase public anon key
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJyYnNqbWZ3YWhhZXJrZmhwZWd2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwODA0MTIsImV4cCI6MjA3NTY1NjQxMn0.AktG-LDkkO-m1eLRtKvukO4qSOjWnU0U6nQZPxFHATY';
    const supabase = window.supabase.createClient(supabaseUrl, supabaseKey);

    preregForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        const emailInput = document.getElementById('email-input');
        const email = emailInput.value.trim();

        // 🔒 Email validation regex
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

        // 🚨 Block if not a valid email
        if (!emailRegex.test(email)) {
            responseMessage.textContent = "Don't Daaymn play, enter a valid email";
            responseMessage.style.color = '#ff4d4d';
            return; // stop the form submission
        }

        try {
            const { data, error } = await supabase
                .from('preregistrations')
                .insert([{ email: email }]);

            if (error) throw error;

            responseMessage.textContent = "Daaymn, you're on the list! We'll be in touch.";
            responseMessage.style.color = '#FC00FF';
            emailInput.value = '';

        } catch (error) {
            if (error.code === '23505') {
                responseMessage.textContent = "Looks like you're already on the list!";
                responseMessage.style.color = '#FC00FF';
            } else {
                responseMessage.textContent = 'Something went wrong. Please try again.';
                responseMessage.style.color = '#ff4d4d';
            }
        }

        setTimeout(() => { responseMessage.textContent = ''; }, 5000);
    });
    
    // --- FINAL, CLEANED HOVER LOGIC ---
    const screenshots = document.querySelectorAll('.bg-ss');
    const captionDisplay = document.getElementById('hover-caption-display');

    screenshots.forEach(ss => {
        ss.addEventListener('mouseenter', () => {
            if (ss.dataset.caption) {
                captionDisplay.textContent = ss.dataset.caption;
                captionDisplay.style.opacity = '1';
                captionDisplay.style.transform = 'translateX(-50%) translateY(0)';
            }
        });

        ss.addEventListener('mouseleave', () => {
            captionDisplay.style.opacity = '0';
            captionDisplay.style.transform = 'translateX(-50%) translateY(20px)';
        });
    });
});
