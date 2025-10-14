import React, { useState, useEffect } from 'react';

export default function AdminScheduleExceptions() {
  const [exceptions, setExceptions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ schedule_id: '', exception_date: '', disable_run: false, disable_online: false });

  // Load all exceptions on mount
  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const res = await fetch('/api/admin/trips/exceptions');
        const data = await res.json();
        setExceptions(data);
      } catch (err) {
        console.error('Error fetching exceptions:', err);
      }
      setLoading(false);
    };
    load();
  }, []);

  const handleFormChange = e => {
    const { name, value, type, checked } = e.target;
    setForm(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value
    }));
  };

  const openForm = () => {
    setForm({ schedule_id: '', exception_date: '', disable_run: false, disable_online: false });
    setShowForm(true);
  };

  const submitException = async () => {
    try {
      await fetch('/api/trips/exceptions/update', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form)
      });
      // reload exceptions
      const res = await fetch('/api/admin/trips/exceptions');
      const data = await res.json();
      setExceptions(data);
      setShowForm(false);
    } catch (err) {
      console.error('Error updating exception:', err);
    }
  };

  return (
    <div className="p-6 bg-white rounded shadow">
      <h1 className="text-2xl font-bold mb-4">Excepții Curse</h1>
      {loading ? (
        <p>Se încarcă excepțiile...</p>
      ) : (
        <>
          <h2 className="text-xl font-semibold mb-2">Lista Excepțiilor</h2>
          <table className="w-full table-auto border-collapse mb-6">
            <thead>
              <tr className="bg-gray-100">
                <th className="border px-4 py-2">Data</th>
                <th className="border px-4 py-2">Rută</th>
                <th className="border px-4 py-2 text-center">Ora</th>
                <th className="border px-4 py-2 text-center">Op. Generare</th>
                <th className="border px-4 py-2 text-center">Op. Rezervări</th>
              </tr>
            </thead>
            <tbody>
              {exceptions.map(exc => (
                <tr key={`${exc.schedule_id}-${exc.exception_date}`} className="hover:bg-gray-50">
                  <td className="border px-4 py-2 text-center">{exc.exception_date}</td>
                  <td className="border px-4 py-2">{exc.route_name}</td>
                  <td className="border px-4 py-2 text-center">{exc.departure}</td>
                  <td className="border px-4 py-2 text-center">{exc.disable_run ? 'Da' : 'Nu'}</td>
                  <td className="border px-4 py-2 text-center">{exc.disable_online ? 'Da' : 'Nu'}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <button
            className="bg-blue-600 text-white px-4 py-2 rounded"
            onClick={openForm}
          >Adaugă excepție</button>

          {showForm && (
            <div className="mt-4 border p-4 rounded bg-gray-50">
              <h3 className="text-lg font-medium mb-2">Nouă Excepție</h3>
              <div className="mb-2">
                <label className="block mb-1">Schedule ID:</label>
                <input
                  type="text"
                  name="schedule_id"
                  value={form.schedule_id}
                  onChange={handleFormChange}
                  className="border rounded w-full p-1"
                  placeholder="ID din route_schedules"
                />
              </div>
              <div className="mb-2">
                <label className="block mb-1">Data (YYYY-MM-DD):</label>
                <input
                  type="text"
                  name="exception_date"
                  value={form.exception_date}
                  onChange={handleFormChange}
                  className="border rounded w-full p-1"
                  placeholder="2025-08-15"
                />
              </div>
              <div className="flex items-center mb-2">
                <input
                  type="checkbox"
                  name="disable_run"
                  checked={form.disable_run}
                  onChange={handleFormChange}
                  className="mr-2"
                />
                <label>Oprire totală</label>
              </div>
              <div className="flex items-center mb-4">
                <input
                  type="checkbox"
                  name="disable_online"
                  checked={form.disable_online}
                  onChange={handleFormChange}
                  className="mr-2"
                />
                <label>Oprire rezervări online</label>
              </div>
              <div className="flex space-x-2">
                <button
                  className="bg-green-600 text-white px-3 py-1 rounded"
                  onClick={submitException}
                >Salvează</button>
                <button
                  className="bg-gray-400 text-white px-3 py-1 rounded"
                  onClick={() => setShowForm(false)}
                >Anulează</button>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
