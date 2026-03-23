require('dotenv').config();
const express = require('express');

const app = express();
app.use(express.json());

// ヘルスチェック
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// TODO: ルートを追加していく
// app.use('/v1/auth',    require('./routes/auth'));
// app.use('/v1/avatar',  require('./routes/avatar'));
// app.use('/v1/tasks',   require('./routes/tasks'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API server running on port ${PORT}`);
});
