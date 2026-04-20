const db = require('../config/database');

// Get all notifications
exports.getNotifications = async (req, res) => {
  try {
    const { limit = 20, unread_only = false } = req.query;

    let query = `
      SELECT n.*, sn.node_name, sn.location
      FROM notifications n
      LEFT JOIN sensor_nodes sn ON n.node_id = sn.node_id
    `;

    if (unread_only === 'true') {
      query += ' WHERE n.is_read = FALSE';
    }

    query += ' ORDER BY n.created_at DESC LIMIT ?';

    const [notifications] = await db.query(query, [parseInt(limit)]);

    res.json({
      success: true,
      data: notifications
    });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Mark notification as read
exports.markAsRead = async (req, res) => {
  try {
    const { id } = req.params;

    await db.query('UPDATE notifications SET is_read = TRUE WHERE id = ?', [id]);

    res.json({
      success: true,
      message: 'Notifikasi ditandai sebagai dibaca'
    });
  } catch (error) {
    console.error('Mark as read error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

// Get unread count
exports.getUnreadCount = async (req, res) => {
  try {
    const [result] = await db.query(
      'SELECT COUNT(*) as count FROM notifications WHERE is_read = FALSE'
    );

    res.json({
      success: true,
      data: { count: result[0].count }
    });
  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
