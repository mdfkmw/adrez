import React, { useState, useEffect, useMemo } from 'react';
import axios from 'axios';

export default function DiscountAppliesTab() {
  const [discounts, setDiscounts] = useState([]);
  const [schedules, setSchedules] = useState([]);
  const [selDisc, setSelDisc] = useState('');
  const [checked, setChecked] = useState(new Set());

  // sorting state
  const [sortConfig, setSortConfig] = useState({ key: 'route_name', direction: 'asc' });

  useEffect(() => {
    axios.get('/api/discount-types').then(r => setDiscounts(r.data));
    axios.get('/api/discount-types/schedules/all').then(r => setSchedules(r.data));
  }, []);

  useEffect(() => {
    if (!selDisc) {
      setChecked(new Set());
      return;
    }
    axios.get(`/api/discount-types/${selDisc}/schedules`).then(r => setChecked(new Set(r.data)));
  }, [selDisc]);

  function toggle(id) {
    setChecked(prev => {
      const nxt = new Set(prev);
      nxt.has(id) ? nxt.delete(id) : nxt.add(id);
      return nxt;
    });
  }

  function save() {
    axios
      .put(`/api/discount-types/${selDisc}/schedules`, { scheduleIds: Array.from(checked) })
      .then(() => alert('Salvat!'))
      .catch(() => alert('Eroare la salvare'));
  }

  // sort handler
  const requestSort = key => {
    let direction = 'asc';
    if (sortConfig.key === key && sortConfig.direction === 'asc') {
      direction = 'desc';
    }
    setSortConfig({ key, direction });
  };

  const sortedSchedules = useMemo(() => {
    const sortable = [...schedules];
    sortable.sort((a, b) => {
      let aVal = a[sortConfig.key];
      let bVal = b[sortConfig.key];
      if (typeof aVal === 'string') aVal = aVal.toLowerCase();
      if (typeof bVal === 'string') bVal = bVal.toLowerCase();
      if (aVal < bVal) return sortConfig.direction === 'asc' ? -1 : 1;
      if (aVal > bVal) return sortConfig.direction === 'asc' ? 1 : -1;
      return 0;
    });
    return sortable;
  }, [schedules, sortConfig]);

  return (
    <div className="p-6">
      <h2 className="text-lg font-semibold mb-4">Se aplică la</h2>

      <div className="mb-4">
        <select
          className="p-2 text-sm border rounded"
          value={selDisc}
          onChange={e => setSelDisc(e.target.value)}
        >
          <option value="">Alege reducere…</option>
          {discounts.map(d => (
            <option key={d.id} value={d.id}>
              {d.label}
            </option>
          ))}
        </select>
      </div>

      <div className="overflow-x-auto">
        <table className="w-auto text-sm table-auto border-collapse">
          <thead>
            <tr>
              <th
                onClick={() => requestSort('route_name')}
                className="p-1 border text-left cursor-pointer select-none bg-gray-200"
              >
                Traseu {sortConfig.key === 'route_name' ? (sortConfig.direction === 'asc' ? '▲' : '▼') : ''}
              </th>
              <th
                onClick={() => requestSort('departure')}
                className="p-1 border text-left cursor-pointer select-none bg-gray-200"
              >
                Ora {sortConfig.key === 'departure' ? (sortConfig.direction === 'asc' ? '▲' : '▼') : ''}
              </th>
              <th
                onClick={() => requestSort('direction')}
                className="p-1 border text-left cursor-pointer select-none bg-gray-200"
              >
                Direcție {sortConfig.key === 'direction' ? (sortConfig.direction === 'asc' ? '▲' : '▼') : ''}
              </th>
              <th className="p-1 border text-left bg-gray-200">Aplică</th>
            </tr>
          </thead>
          <tbody>
            {sortedSchedules.map((s, idx) => (
              <tr
                key={s.id}
                className={idx % 2 === 0 ? 'bg-white' : 'bg-gray-50'}
              >
                <td className="p-1 border">{s.route_name}</td>
                <td className="p-1 border">{s.departure}</td>
                <td className="p-1 border">{s.direction}</td>
                <td className="p-1 border text-center">
                  <input
                    type="checkbox"
                    checked={checked.has(s.id)}
                    onChange={() => toggle(s.id)}
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="text-left mt-4">
        <button
          className="px-3 py-1 text-sm bg-green-600 text-white rounded"
          disabled={!selDisc}
          onClick={save}
        >
          Salvează
        </button>
      </div>
    </div>
  );
}
