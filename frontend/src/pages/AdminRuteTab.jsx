import React, { useState, useEffect, useMemo } from 'react';
import axios from 'axios';

/**
 * Tab-ul „Trasee” din pagina de administrare.
 * — Afișează toate rutele într-un tabel simplu (stil identic cu AdminDiscountType / AdminDrivers)
 * — Coloane: nume + buton „Editează”
 * — Sortare asc/desc după nume la click pe header
 */
export default function AdminRouteTab() {
  const [routes, setRoutes] = useState([]);

  // ordonare simplă (similar cu AdminDiscountType)
  const [sortConfig, setSortConfig] = useState({ key: 'name', direction: 'asc' });

  /*────────────────────────── Fetch */
  const fetchRoutes = async () => {
    try {
      const res = await axios.get('/api/routes');
      setRoutes(res.data);
    } catch (err) {
      console.error('Eroare la încărcarea rutelor:', err);
      alert('Nu s-au putut încărca rutele');
    }
  };

  useEffect(() => {
    fetchRoutes();
  }, []);

  /*────────────────────────── Sortare */
  const requestSort = (key) => {
    let direction = 'asc';
    if (sortConfig.key === key && sortConfig.direction === 'asc') direction = 'desc';
    setSortConfig({ key, direction });
  };

  const sortedRoutes = useMemo(() => {
    const sortable = [...routes];
    sortable.sort((a, b) => {
      let aVal = (a[sortConfig.key] || '').toLowerCase();
      let bVal = (b[sortConfig.key] || '').toLowerCase();
      if (aVal < bVal) return sortConfig.direction === 'asc' ? -1 : 1;
      if (aVal > bVal) return sortConfig.direction === 'asc' ? 1 : -1;
      return 0;
    });
    return sortable;
  }, [routes, sortConfig]);

  /*────────────────────────── Edit */
  const handleEdit = (routeId) => {
    // Deschide în tab nou (mai sigur cu noopener/noreferrer)
    window.open(`/admin/routes/${routeId}/edit`, '_blank', 'noopener,noreferrer');
  };

  /*────────────────────────── UI */
  return (
    <div className="overflow-x-auto">
      <h2 className="text-lg font-semibold mb-4">Trasee</h2>

      <table className="w-auto text-sm table-auto border-collapse">
        <thead>
          <tr>
            <th
              onClick={() => requestSort('name')}
              className="p-1 border text-left cursor-pointer select-none bg-gray-200"
            >
              Nume
              {sortConfig.key === 'name' ? (sortConfig.direction === 'asc' ? ' ▲' : ' ▼') : ''}
            </th>
            <th className="p-1 border text-left bg-gray-200">Acțiuni</th>
          </tr>
        </thead>
        <tbody>
          {sortedRoutes.map((route, idx) => (
            <tr key={route.id} className={idx % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
              <td className="p-1 border">{route.name}</td>
              <td className="p-1 border">
                <button
                  className="px-2 py-1 text-xs bg-blue-500 text-white rounded"
                  onClick={() => handleEdit(route.id)}
                  title="Deschide în tab nou"
                >
                  Editează
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}