document.addEventListener('DOMContentLoaded', () => {
  const preregForm = document.getElementById('prereg-form');
  const responseMessage = document.getElementById('response-message');
  const supabaseUrl = 'https://rrbsjmfwahaerkfhpegv.supabase.co';
  const supabaseKey = 'YOUR_SUPABASE_PUBLIC_ANON_KEY';
  const supabase = window.supabase.createClient(supabaseUrl, supabaseKey);

  preregForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    const emailInput = document.getElementById('email-input');
    const email = emailInput.value.trim();

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!emailRegex.test(email)) {
      responseMessage.textContent = "Don't Daaymn play, enter a valid email";
      responseMessage.style.color = '#ff4d4d';
      return;
    }

    try {
      const { error } = await supabase.from('preregistrations').insert([{ email }]);
      if (error) throw error;
      responseMessage.textContent = "Daaymn, you're on the list! We'll be in touch.";
      responseMessage.style.color = '#FC00FF';
      emailInput.value = '';
    } catch (error) {
      responseMessage.textContent = 'Something went wrong. Please try again.';
      responseMessage.style.color = '#ff4d4d';
    }

    setTimeout(() => (responseMessage.textContent = ''), 5000);
  });

  // --- Hover caption logic ---
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
