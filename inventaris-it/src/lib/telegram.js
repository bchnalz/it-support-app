/**
 * Telegram Bot Integration
 * 
 * Setup Steps:
 * 1. Create a bot via @BotFather on Telegram
 * 2. Get the bot token
 * 3. Add VITE_TELEGRAM_BOT_TOKEN to your .env file
 * 4. Users link their account by sending /start to the bot
 * 5. Store telegram_id in users table
 * 
 * Environment Variable:
 * VITE_TELEGRAM_BOT_TOKEN=your_bot_token_here
 */

const TELEGRAM_BOT_TOKEN = import.meta.env.VITE_TELEGRAM_BOT_TOKEN;
const TELEGRAM_API_URL = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}`;

/**
 * Send a message to a Telegram user
 * @param {string} chatId - User's Telegram chat ID (stored in users.telegram_id)
 * @param {string} message - Message text to send
 * @returns {Promise<boolean>} Success status
 */
export const sendTelegramMessage = async (chatId, message) => {
  if (!TELEGRAM_BOT_TOKEN) {
    console.warn('Telegram bot token not configured');
    return false;
  }

  if (!chatId) {
    console.warn('Telegram chat ID not provided');
    return false;
  }

  try {
    const response = await fetch(`${TELEGRAM_API_URL}/sendMessage`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        chat_id: chatId,
        text: message,
        parse_mode: 'HTML', // Allows HTML formatting
      }),
    });

    const data = await response.json();
    
    if (!data.ok) {
      console.error('Telegram API error:', data);
      return false;
    }

    return true;
  } catch (error) {
    console.error('Error sending Telegram message:', error);
    return false;
  }
};

/**
 * Send a task assignment notification via Telegram
 * @param {string} chatId - IT Support's Telegram chat ID
 * @param {Object} task - Task details
 */
export const sendTaskAssignmentNotification = async (chatId, task) => {
  const message = `
🔔 <b>Tugas Baru!</b>

📋 <b>${task.task_number}</b>
${task.title}

🎯 SKP: ${task.skp_code} - ${task.skp_name}
⚡ Prioritas: ${task.priority_label}
👤 Dari: ${task.assigned_by_name}

Silakan login ke sistem untuk konfirmasi tugas.
  `.trim();

  return await sendTelegramMessage(chatId, message);
};

/**
 * Send a task completion notification via Telegram
 * @param {string} chatId - Helpdesk's Telegram chat ID
 * @param {Object} task - Task details
 */
export const sendTaskCompletionNotification = async (chatId, task) => {
  const message = `
✅ <b>Tugas Selesai!</b>

📋 <b>${task.task_number}</b>
${task.title}

👤 Petugas: ${task.it_support_name}
⏱️ Durasi: ${task.duration}

${task.completion_notes ? `📝 Catatan:\n${task.completion_notes}` : ''}
  `.trim();

  return await sendTelegramMessage(chatId, message);
};

/**
 * Send a reminder notification via Telegram
 * @param {string} chatId - User's Telegram chat ID
 * @param {string} message - Custom reminder message
 */
export const sendReminderNotification = async (chatId, message) => {
  const formattedMessage = `
⏰ <b>Reminder</b>

${message}
  `.trim();

  return await sendTelegramMessage(chatId, formattedMessage);
};

/**
 * Verify Telegram webhook (for advanced setup with backend)
 * This requires a backend endpoint to receive webhook updates
 * 
 * For simple setup, you can use polling instead:
 * - Create a backend service that polls getUpdates endpoint
 * - Process /start command to get chat_id
 * - Store chat_id in users.telegram_id
 */
export const setupTelegramWebhook = async (webhookUrl) => {
  if (!TELEGRAM_BOT_TOKEN) {
    console.warn('Telegram bot token not configured');
    return false;
  }

  try {
    const response = await fetch(`${TELEGRAM_API_URL}/setWebhook`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        url: webhookUrl,
      }),
    });

    const data = await response.json();
    return data.ok;
  } catch (error) {
    console.error('Error setting up Telegram webhook:', error);
    return false;
  }
};

/**
 * Get bot info (useful for testing)
 */
export const getTelegramBotInfo = async () => {
  if (!TELEGRAM_BOT_TOKEN) {
    console.warn('Telegram bot token not configured');
    return null;
  }

  try {
    const response = await fetch(`${TELEGRAM_API_URL}/getMe`);
    const data = await response.json();
    
    if (data.ok) {
      return data.result;
    }
    
    return null;
  } catch (error) {
    console.error('Error getting bot info:', error);
    return null;
  }
};

export default {
  sendTelegramMessage,
  sendTaskAssignmentNotification,
  sendTaskCompletionNotification,
  sendReminderNotification,
  setupTelegramWebhook,
  getTelegramBotInfo,
};
