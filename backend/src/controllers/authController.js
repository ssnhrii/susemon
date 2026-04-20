const db = require('../config/database');
const jwt = require('jsonwebtoken');

exports.login = async (req, res) => {
  try {
    const { ip_address, access_code } = req.body;

    if (!ip_address || !access_code) {
      return res.status(400).json({
        success: false,
        message: 'IP Address dan Access Code harus diisi'
      });
    }

    // Check user
    const [users] = await db.query(
      'SELECT * FROM users WHERE ip_address = ? AND access_code = ?',
      [ip_address, access_code]
    );

    if (users.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'IP Address atau Access Code tidak valid'
      });
    }

    const user = users[0];

    // Update last login
    await db.query(
      'UPDATE users SET last_login = NOW() WHERE id = ?',
      [user.id]
    );

    // Generate JWT token
    const token = jwt.sign(
      { id: user.id, ip_address: user.ip_address },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      success: true,
      message: 'Login berhasil',
      data: {
        token,
        user: {
          id: user.id,
          ip_address: user.ip_address,
          name: user.name
        }
      }
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan server'
    });
  }
};

exports.verify = async (req, res) => {
  res.json({
    success: true,
    message: 'Token valid',
    data: { user: req.user }
  });
};
