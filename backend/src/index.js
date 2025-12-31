const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const { initializeDatabase } = require('./database/db');

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Routes
const secretaryRoute = require('./routes/secretary');
const expertRoute = require('./routes/expert');
const sessionsRoute = require('./routes/sessions');
const devicesRoute = require('./routes/devices');

app.use('/api/secretary', secretaryRoute);
app.use('/api/expert', expertRoute);
app.use('/api/sessions', sessionsRoute);
app.use('/api/devices', devicesRoute);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Initialize database and start server
async function startServer() {
  try {
    // Initialize database tables
    if (process.env.DATABASE_URL) {
      try {
        await initializeDatabase();
        console.log('✅ Database initialized successfully');
      } catch (dbError) {
        console.warn('⚠️  Database initialization failed, continuing without database:', dbError.message);
        console.warn('⚠️  Some features (session history, device registry) will be unavailable');
      }
    } else {
      console.warn('⚠️  DATABASE_URL not configured, running without database');
      console.warn('⚠️  Session history and device registry features will be unavailable');
    }

    app.listen(PORT, () => {
      console.log(`Toni backend server running on port ${PORT}`);
      console.log(`AI endpoint: ${process.env.BACKEND_AI_ENDPOINT || 'Not configured'}`);
      console.log(`Database: ${process.env.DATABASE_URL ? 'Connected' : 'Not configured'}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();

