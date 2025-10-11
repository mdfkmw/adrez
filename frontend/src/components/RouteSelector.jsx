// 📁 components/RouteSelector.jsx
import React from 'react';

// Ordine de afișare sugerată (opțională)
const turOrder = [
  'Botoșani – Iași',
  'Botoșani – București',
  'Dorohoi – Botoșani – Iași',
  'Botoșani – Brașov',
  'Iași – Rădăuți'
];

const returOrder = [
  'Iași – Botoșani',
  'București – Botoșani',
  'Iași – Botoșani – Dorohoi',
  'Brașov – Botoșani',
  'Rădăuți – Iași'
];

const sortByOrder = (list, order) => {
  return [...list].sort((a, b) => order.indexOf(a.name) - order.indexOf(b.name));
};

export default function RouteSelector({ routes, selectedRoute, setSelectedRoute }) {
  const turRoutes = routes.filter(route => turOrder.includes(route.name));
  const returRoutes = routes.filter(route => returOrder.includes(route.name));

  const sortedTur = sortByOrder(turRoutes, turOrder);
  const sortedRetur = sortByOrder(returRoutes, returOrder);

  return (
    <div className="space-y-4  w-full">
      <div>
        <h2 className="font-bold text-lg mb-0">Tur</h2>
        <div className="flex flex-nowrap gap-2 w-full overflow-x-auto py-1">
          {sortedTur.map((route) => (
            <button
              key={route.id}
              className={`px-3 py-1 rounded border ${
                selectedRoute?.id === route.id ? 'bg-blue-500 text-white' : 'bg-white'
              }`}
              onClick={() => setSelectedRoute(route)}
            >
              {route.name}
            </button>
          ))}
        </div>
      </div>
      <div>
        <h2 className="font-bold text-lg mt-4 mb-0">Retur</h2>
        <div className="flex flex-nowrap gap-2 w-full overflow-x-auto py-1">
          {sortedRetur.map((route) => (
            <button
              key={route.id}
              className={`px-3 py-1 rounded border ${
                selectedRoute?.id === route.id ? 'bg-blue-500 text-white' : 'bg-white'
              }`}
              onClick={() => setSelectedRoute(route)}
            >
              {route.name}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
