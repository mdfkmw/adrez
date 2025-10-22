import React, { useEffect, useState, useMemo } from 'react';

export default function AdminEmployees() {
  const [employees, setEmployees] = useState([]);
  const [operators, setOperators] = useState([]);
  const [loading, setLoading] = useState(true);

  // modal state
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({
    id: null,
    name: '',
    phone: '',
    email: '',
    role: 'driver',
    active: true,
    operator_id: operators.length ? operators[0].id : null,
  });

  // sorting state
  const [sortConfig, setSortConfig] = useState({ key: 'id', direction: 'asc' });

  useEffect(() => {
    fetchAll();
    fetchOperators();
  }, []);

  const fetchAll = async () => {
    setLoading(true);
    const res = await fetch('/api/employees');
    const data = await res.json();
    setEmployees(data);
    setLoading(false);
  };

  const fetchOperators = async () => {
    const res = await fetch('/api/operators');
    const data = await res.json();
    setOperators(data);
    setForm(f => ({ ...f, operator_id: data[0]?.id }));
  };

  const openNew = () => {
    setForm({
      id: null,
      name: '',
      phone: '',
      email: '',
      role: 'driver',
      active: true,
      operator_id: operators[0]?.id || null,
    });
    setShowModal(true);
  };

  const openEdit = emp => {
    setForm({ ...emp });
    setShowModal(true);
  };

  const closeModal = () => setShowModal(false);

  const save = async () => {
    const method = form.id ? 'PUT' : 'POST';
    const url = form.id
      ? `/api/employees/${form.id}`
      : `/api/employees`;
    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form),
    });
    if (!res.ok) {
      console.error('save failed', await res.text());
      return;
    }
    await fetchAll();
    closeModal();
  };

  const remove = async id => {
    if (!window.confirm('Șterge angajatul?')) return;
    await fetch(`/api/employees/${id}`, { method: 'DELETE' });
    fetchAll();
  };

  // Handle sorting
  const requestSort = key => {
    let direction = 'asc';
    if (sortConfig.key === key && sortConfig.direction === 'asc') {
      direction = 'desc';
    }
    setSortConfig({ key, direction });
  };

  const sortedEmployees = useMemo(() => {
    const sortable = [...employees];
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
  }, [employees, sortConfig]);

  if (loading) return <p>Se încarcă angajații…</p>;

  return (
    <div>
      <h2 className="text-lg font-semibold mb-4">Angajați</h2>
      <button
        onClick={openNew}
        className="mb-4 px-3 py-1 text-sm bg-green-600 text-white rounded"
      >
        + Adaugă
      </button>

      <div className="overflow-x-auto">
        <table className="w-auto text-sm table-auto border-collapse">
          <thead>
            <tr>
              <th
                onClick={() => requestSort('id')}
                className="p-1 border text-left cursor-pointer select-none"
              >
                # {sortConfig.key === 'id' ? (sortConfig.direction === 'asc' ? '▲' : '▼') : ''}
              </th>
              <th
                onClick={() => requestSort('name')}
                className="p-1 border text-left cursor-pointer select-none"
              >
                Nume {sortConfig.key === 'name' ? (sortConfig.direction === 'asc' ? '▲' : '▼') : ''}
              </th>
              <th
                onClick={() => requestSort('phone')}
                className="p-1 border text-left cursor-pointer select-none"
              >
                Telefon {sortConfig.key === 'phone' ? (sortConfig.direction === 'asc' ? '▲' : '▼') : ''}
              </th>
              <th
                onClick={() => requestSort('email')}
                className="p-1 border text-left cursor-pointer select-none"
              >
                Email {sortConfig.key === 'email' ? (sortConfig.direction === 'asc' ? '▲' : '▼') : ''}
              </th>
              <th
                onClick={() => requestSort('role')}
                className="p-1 border text-left cursor-pointer select-none"
              >
                Rol {sortConfig.key === 'role' ? (sortConfig.direction === 'asc' ? '▲' : '▼') : ''}
              </th>
              <th
                onClick={() => requestSort('active')}
                className="p-1 border text-left cursor-pointer select-none"
              >
                Activ {sortConfig.key === 'active' ? (sortConfig.direction === 'asc' ? '▲' : '▼') : ''}
              </th>
              <th
                onClick={() => requestSort('operator_id')}
                className="p-1 border text-left cursor-pointer select-none"
              >
                Operator {sortConfig.key === 'operator_id' ? (sortConfig.direction === 'asc' ? '▲' : '▼') : ''}
              </th>
              <th className="p-1 border text-left">Acțiuni</th>
            </tr>
          </thead>
          <tbody>
            {sortedEmployees.map((emp, idx) => (
              <tr
                key={emp.id}
                className={idx % 2 === 0 ? 'bg-white' : 'bg-gray-50'}
              >
                <td className="p-1 border">{emp.id}</td>
                <td className="p-1 border">{emp.name}</td>
                <td className="p-1 border">{emp.phone || '—'}</td>
                <td className="p-1 border">{emp.email || '—'}</td>
                <td className="p-1 border">{emp.role}</td>
                <td className="p-1 border">
                  <input
                    type="checkbox"
                    checked={emp.active}
                    onChange={async () => {
                      await fetch(
                        `/api/employees/${emp.id}`,
                        {
                          method: 'PATCH',
                          headers: { 'Content-Type': 'application/json' },
                          body: JSON.stringify({ active: !emp.active }),
                        }
                      );
                      fetchAll();
                    }}
                  />
                </td>
                <td className="p-1 border">
                  {operators.find(o => o.id === emp.operator_id)?.name || '—'}
                </td>
                <td className="p-1 border space-x-2">
                  <button
                    onClick={() => openEdit(emp)}
                    className="px-2 py-1 text-xs bg-blue-500 text-white rounded"
                  >
                    Editează
                  </button>
                  <button
                    onClick={() => remove(emp.id)}
                    className="px-2 py-1 text-xs bg-red-500 text-white rounded"
                  >
                    Șterge
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showModal && (
        <div className="fixed inset-0 bg-black bg-opacity-30 flex items-center justify-center">
          <div className="bg-white p-6 rounded shadow-lg w-80">
            <h3 className="mb-4 text-lg font-semibold">
              {form.id ? 'Editează' : 'Adaugă'} angajat
            </h3>

            <label className="block mb-2 text-sm">
              Nume
              <input
                className="w-full p-2 border rounded text-sm"
                value={form.name}
                onChange={e => setForm({ ...form, name: e.target.value })}
              />
            </label>
            <label className="block mb-2 text-sm">
              Telefon
              <input
                className="w-full p-2 border rounded text-sm"
                value={form.phone}
                onChange={e => setForm({ ...form, phone: e.target.value })}
              />
            </label>
            <label className="block mb-2 text-sm">
              Email
              <input
                className="w-full p-2 border rounded text-sm"
                value={form.email}
                onChange={e => setForm({ ...form, email: e.target.value })}
              />
            </label>
            <label className="block mb-2 text-sm">
              Rol
              <select
                className="w-full p-2 border rounded text-sm"
                value={form.role}
                onChange={e => setForm({ ...form, role: e.target.value })}
              >
                <option value="driver">Driver</option>
                <option value="agent">Agent</option>
              </select>
            </label>
            <label className="block mb-2 text-sm flex items-center">
              <input
                type="checkbox"
                className="mr-2"
                checked={form.active}
                onChange={e => setForm({ ...form, active: e.target.checked })}
              />
              Activ
            </label>
            <label className="block mb-4 text-sm">
              Operator
              <select
                className="w-full p-2 border rounded text-sm"
                value={form.operator_id || ''}
                onChange={e => setForm({ ...form, operator_id: Number(e.target.value) })}
              >
                {operators.map(op => (
                  <option key={op.id} value={op.id}>
                    {op.name}
                  </option>
                ))}
              </select>
            </label>

            <div className="text-right space-x-2">
              <button
                onClick={closeModal}
                className="px-3 py-1 bg-gray-300 rounded text-sm"
              >
                Anulează
              </button>
              <button
                onClick={save}
                className="px-3 py-1 bg-green-600 text-white rounded text-sm"
              >
                Salvează
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
