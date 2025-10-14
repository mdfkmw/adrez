// db.js — MariaDB (mysql2/promise) cu adaptor compatibil "pg"
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.MDB_HOST,
  user: process.env.MDB_USER,
  password: process.env.MDB_PASS,
  database: process.env.MDB_NAME,
  port: Number(process.env.MDB_PORT || 3306),
  connectionLimit: 10,
  multipleStatements: false,
  charset: 'utf8mb4',
  decimalNumbers: true
});

// Adaptor ca să mimeze API-ul pg: pool.query() => { rows, rowCount, insertId }
const adapter = {
  async query(sql, params = []) {
    const [res] = await pool.execute(sql, params);

    if (Array.isArray(res)) {
      return { rows: res, rowCount: res.length, insertId: null, raw: res };
    }

    return {
      rows: [],
      rowCount: typeof res.affectedRows === 'number' ? res.affectedRows : 0,
      insertId: typeof res.insertId === 'number' ? res.insertId : null,
      raw: res
    };
  },

  async getConnection() {
    return pool.getConnection();
  },

  pool
};

module.exports = adapter;
