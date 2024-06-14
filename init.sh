#!/bin/bash

# Create project directories
mkdir -p project/backend/config project/backend/routes project/backend/models project/backend/middleware project/frontend

# Create .env file
cat <<EOL > project/.env
DATABASE_TYPE=mysql
DATABASE_HOST=localhost
DATABASE_PORT=3306
DATABASE_NAME=myapp
DATABASE_USER=root
DATABASE_PASSWORD=password
SECRET_KEY=your_secret_key
EOL

# Create bunfig.toml
cat <<EOL > project/bunfig.toml
[backend]
entry = "backend/app.js"
port = 3000
EOL

# Create package.json
cat <<EOL > project/package.json
{
  "name": "crud-login-app",
  "version": "1.0.0",
  "main": "backend/app.js",
  "scripts": {
    "start": "bun run backend/app.js"
  },
  "dependencies": {
    "bcrypt": "^5.0.1",
    "body-parser": "^1.19.0",
    "dotenv": "^10.0.0",
    "express": "^4.17.1",
    "jsonwebtoken": "^8.5.1",
    "mysql2": "^2.2.5",
    "pg": "^8.6.0",
    "pg-hstore": "^2.3.4",
    "sequelize": "^6.6.5"
  }
}
EOL

# Create backend files
cat <<EOL > project/backend/app.js
const express = require('express');
const bodyParser = require('body-parser');
const { initDb } = require('./models');
const authRoutes = require('./routes/auth');
const crudRoutes = require('./routes/crud');

require('dotenv').config();

const app = express();

app.use(bodyParser.json());

app.use('/auth', authRoutes);
app.use('/crud', crudRoutes);

initDb().then(() => {
  app.listen(3000, () => {
    console.log('Server is running on port 3000');
  });
});
EOL

cat <<EOL > project/backend/config/database.js
const { Sequelize } = require('sequelize');
require('dotenv').config();

const databaseType = process.env.DATABASE_TYPE || 'mysql';

const sequelize = new Sequelize(
  process.env.DATABASE_NAME,
  process.env.DATABASE_USER,
  process.env.DATABASE_PASSWORD,
  {
    host: process.env.DATABASE_HOST,
    port: process.env.DATABASE_PORT,
    dialect: databaseType,
    logging: false,
  }
);

module.exports = sequelize;
EOL

cat <<EOL > project/backend/models/index.js
const sequelize = require('../config/database');
const User = require('./user');

const initDb = async () => {
  await sequelize.sync({ force: true });
};

module.exports = { initDb, User };
EOL

cat <<EOL > project/backend/models/user.js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const User = sequelize.define('User', {
  username: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
  },
  password: {
    type: DataTypes.STRING,
    allowNull: false,
  },
});

module.exports = User;
EOL

cat <<EOL > project/backend/routes/auth.js
const express = require('express');
const router = express.Router();
const { User } = require('../models');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  const user = await User.findOne({ where: { username } });
  if (!user || !bcrypt.compareSync(password, user.password)) {
    return res.status(401).send('Invalid credentials');
  }
  const token = jwt.sign({ userId: user.id }, process.env.SECRET_KEY);
  res.json({ token });
});

router.post('/register', async (req, res) => {
  const { username, password } = req.body;
  const hashedPassword = bcrypt.hashSync(password, 10);
  const user = await User.create({ username, password: hashedPassword });
  res.status(201).send('User registered');
});

module.exports = router;
EOL

cat <<EOL > project/backend/routes/crud.js
const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');

let items = [];

router.use(authMiddleware);

router.get('/', (req, res) => {
  res.json(items);
});

router.post('/', (req, res) => {
  const item = req.body;
  items.push(item);
  res.status(201).json(item);
});

router.put('/:id', (req, res) => {
  const { id } = req.params;
  const newItem = req.body;
  items = items.map(item => item.id === id ? newItem : item);
  res.json(newItem);
});

router.delete('/:id', (req, res) => {
  const { id } = req.params;
  items = items.filter(item => item.id !== id);
  res.status(204).send();
});

module.exports = router;
EOL

cat <<EOL > project/backend/middleware/authMiddleware.js
const jwt = require('jsonwebtoken');

module.exports = function (req, res, next) {
  const token = req.headers['authorization'];
  if (!token) return res.status(401).send('Access denied');
  
  try {
    const verified = jwt.verify(token, process.env.SECRET_KEY);
    req.user = verified;
    next();
  } catch (err) {
    res.status(400).send('Invalid token');
  }
};
EOL

# Create frontend files
cat <<EOL > project/frontend/index.html
<!DOCTYPE html>
<html>
<head>
  <title>CRUD App</title>
</head>
<body>
  <h1>CRUD App</h1>
  <div id="app">
    <input type="text" id="item-input" placeholder="Enter item" />
    <button onclick="addItem()">Add Item</button>
    <ul id="items-list"></ul>
  </div>
  <script src="main.js"></script>
</body>
</html>
EOL

cat <<EOL > project/frontend/login.html
<!DOCTYPE html>
<html>
<head>
  <title>Login</title>
</head>
<body>
  <h1>Login</h1>
  <div id="login-form">
    <input type="text" id="username" placeholder="Username" />
    <input type="password" id="password" placeholder="Password" />
    <button onclick="login()">Login</button>
  </div>
  <script src="main.js"></script>
</body>
</html>
EOL

cat <<EOL > project/frontend/main.js
const API_URL = 'http://localhost:3000';

async function login() {
  const username = document.getElementById('username').value;
  const password = document.getElementById('password').value;
  
  const response = await fetch(\`\${API_URL}/auth/login\`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password })
  });
  
  const data = await response.json();
  if (response.ok) {
    localStorage.setItem('token', data.token);
    window.location.href = 'index.html';
  } else {
    alert('Login failed');
  }
}

async function addItem() {
  const item = document.getElementById('item-input').value;
  const token = localStorage.getItem('token');
  
  const response = await fetch(\`\${API_URL}/crud\`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': token },
    body: JSON.stringify({ item })
  });
  
  const newItem = await response.json();
  document.getElementById('items-list').innerHTML += \`<li>\${newItem.item}</li>\`;
}

async function fetchItems() {
  const token = localStorage.getItem('token');
  
  const response = await fetch(\`\${API_URL}/crud\`, {
    headers: { 'Authorization': token }
  });
  
  const items = await response.json();
  const itemsList = document.getElementById('items-list');
  itemsList.innerHTML = '';
  items.forEach(item => {
    itemsList.innerHTML += \`<li>\${item.item}</li>\`;
  });
}

if (localStorage.getItem('token')) {
  fetchItems();
}
EOL

# Install dependencies
cd project
bun install

echo "Project initialized successfully."