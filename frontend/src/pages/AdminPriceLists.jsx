// File: src/pages/AdminPriceLists.jsx
import React, { useState, useEffect } from 'react';

export default function AdminPriceLists() {
  const [routes, setRoutes] = useState([]);
  const [categories, setCategories] = useState([]);
  const [stations, setStations] = useState([]);
  const [stationsRaw, setStationsRaw] = useState([]);
  const [versions, setVersions] = useState([]);
  const [grid, setGrid] = useState({});
const [loadingItems, setLoadingItems] = useState(false);




  const nameToId = React.useMemo(() => {
    const m = new Map();
    stationsRaw.forEach(s => m.set(s.name, s.station_id));
    return m;
  }, [stationsRaw]);

  const [selRoute, setSelRoute] = useState('');
  const [selCategory, setSelCategory] = useState('');
  const [appDate, setAppDate] = useState(new Date().toISOString().slice(0, 10));
  const [selVersion, setSelVersion] = useState('');
  const [oppRouteId, setOppRouteId] = useState(null);

  useEffect(() => {
    fetch('/api/routes').then(r => r.json()).then(setRoutes);
    fetch('/api/pricing-categories').then(r => r.json()).then(setCategories);
  }, []);

  useEffect(() => {
    if (categories.length && !selCategory) {
      setSelCategory(categories[0].id.toString());
    }
  }, [categories]);

  useEffect(() => {
    if (!selRoute) return;
    const routeObj = routes.find(r => r.id === +selRoute);
    setOppRouteId(routeObj?.opposite_route_id || null);

    (async () => {
      try {
        const res = await fetch(`/api/routes/${selRoute}/stations`);
        const data = await res.json();
        const sorted = Array.isArray(data)
          ? data.sort((a,b)=>(a.sequence??0)-(b.sequence??0))
          : [];
        setStationsRaw(sorted);
        const sts = sorted.map(s=>s.name);
        setStations(sts);
        const init = {};
        sts.forEach(from => {
          init[from] = {};
          sts.forEach(to => {
            init[from][to] = { price: '', price_return: '' };
          });
        });
        setGrid(init);
        setVersions([]);
        setSelVersion('');
      } catch (e) {
        console.error('AdminPriceLists: nu am putut încărca stațiile rutei', e);
        setStations([]);
        setGrid({});
        setVersions([]);
        setSelVersion('');
      }
    })();
  }, [selRoute, routes]);

  useEffect(() => {
    if (!selRoute || !selCategory || !appDate) return;
    fetch(`/api/price-lists?route=${selRoute}&category=${+selCategory}&date=${appDate}`)
      .then(r => r.json())
      .then(data => {
        setVersions(data);
        if (data.length) {
          setSelVersion(data[0].id.toString());
        } else {
          setSelVersion('');
          setGrid(prev => {
            const cleared = {};
            Object.keys(prev).forEach(from => {
              cleared[from] = {};
              Object.keys(prev[from]).forEach(to => {
                cleared[from][to] = { price: '', price_return: '' };
              });
            });
            return cleared;
          });
        }
      });
  }, [selRoute, selCategory, appDate]);

  useEffect(() => {
  if (!selVersion) return;
  setLoadingItems(true);
  fetch(`/api/price-lists/${selVersion}/items`)
    .then(r => r.json())
    .then(data => {
      const items = Array.isArray(data) ? data : [];
      setGrid(prev => {
        const copy = JSON.parse(JSON.stringify(prev));
        items.forEach(i => {
          if (copy[i.from_stop]?.[i.to_stop] !== undefined) {
            const formatValue = (val) => {
              if (val == null || isNaN(val)) return '';
              const num = parseFloat(val);
              return Number.isInteger(num) ? num.toString() : num.toString().replace(/\.0+$/, '').replace(/(\.\d*?[1-9])0+$/, '$1');
            };
            copy[i.from_stop][i.to_stop] = {
              price: formatValue(i.price),
              price_return: formatValue(i.price_return)
            };
          }
        });
        return copy;
      });
    })
    .catch(() => {
      // în caz de 500/eroare, golește grila ca să nu crape forEach în altă parte
      setGrid(prev => {
        const copy = JSON.parse(JSON.stringify(prev));
        Object.keys(copy).forEach(from => {
          Object.keys(copy[from]).forEach(to => {
            copy[from][to] = { price: '', price_return: '' };
          });
        });
        return copy;
      });
    })
    .finally(() => setLoadingItems(false));
}, [selVersion]);
;
;

  const copyFromOpposite = async () => {
    if (!selVersion) return alert('Selectează mai întâi o versiune');
    if (!oppRouteId) return alert('Niciun traseu opus definit');
    const res = await fetch(`/api/price-lists/${selVersion}/copy-opposite`, { method: 'POST' });
    if (!res.ok) {
      const err = await res.json();
      return alert(`Eroare: ${err.error}`);
    }
    const { id: newId } = await res.json();
    setSelRoute(oppRouteId.toString());
    setSelVersion(newId.toString());
  };

  const isValidPrice = val => /^\d+(\.\d{0,2})?$/.test(val);

  const handleSave = () => {
    const items = [];
    Object.entries(grid).forEach(([from, row]) => {
      Object.entries(row).forEach(([to, cell]) => {
        if (cell.price !== '') {
          if (!isValidPrice(cell.price) || (cell.price_return && !isValidPrice(cell.price_return))) {
            return alert(`Preț invalid între ${from} și ${to}`);
          }
          items.push({
            from_station_id: nameToId.get(from),
            to_station_id: nameToId.get(to),
            from_stop: from,
            to_stop: to,
            price: parseFloat(cell.price),
            price_return: cell.price_return !== '' ? parseFloat(cell.price_return) : null
          });
        }
      });
    });
    if (!items.length) return alert('Nu ai completat niciun preț');
    fetch('/api/price-lists', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ route: +selRoute, category: +selCategory, effective_from: appDate, name: `${selRoute}-${selCategory}-${appDate}`, version: 1, created_by: 1, items })
    })
      .then(r => { if (!r.ok) throw new Error('Eroare la salvare'); return r.json(); })
      .then(data => { alert('Salvat cu succes! ID: ' + data.id); return fetch(`/api/price-lists?route=${selRoute}&category=${+selCategory}&date=${appDate}`); })
      .then(r => r.json()).then(setVersions)
      .catch(e => alert(e.message));
  };

  return (
    <div className="space-y-4 max-w-full">
      <div className="grid grid-cols-2 gap-x-6 gap-y-2 w-fit text-sm">
        <div className="flex flex-col">
          <label className="text-xs text-gray-700 font-semibold">Traseu:</label>
          <select value={selRoute} onChange={e => setSelRoute(e.target.value)} className="border border-gray-300 rounded px-2 py-1 w-[180px]">
            <option value="">Selectează traseu</option>
            {routes.map(r => <option key={r.id} value={r.id}>{r.name}</option>)}
          </select>
        </div>
        <div className="flex flex-col">
          <label className="text-xs text-gray-700 font-semibold">Categorie:</label>
          <select value={selCategory} onChange={e => setSelCategory(e.target.value)} className="border border-gray-300 rounded px-2 py-1 w-[180px]">
            <option value="">Selectează categorie</option>
            {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </div>
        <div className="flex flex-col">
          <label className="text-xs text-gray-700 font-semibold">Dată aplicare:</label>
          <input type="date" value={appDate} onChange={e => setAppDate(e.target.value)} className="border border-gray-300 rounded px-2 py-1 w-[180px]" />
        </div>
        <div className="flex flex-col">
          <label className="text-xs text-gray-700 font-semibold">Versiune:</label>
          <select value={selVersion} onChange={e => setSelVersion(e.target.value)} className="border border-gray-300 rounded px-2 py-1 w-[180px]">
            <option value="">Selectează versiune</option>
            {versions.map(v => (
              <option key={v.id} value={v.id}>
                {new Date(v.effective_from).toLocaleDateString()} (ver. {v.version})
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="flex space-x-2">
        {oppRouteId && selVersion && (
          <button onClick={copyFromOpposite} className="px-2 py-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded">Copiere</button>
        )}
        <button onClick={handleSave} className="px-2 py-1 bg-blue-600 hover:bg-blue-700 text-white rounded">Salvează</button>
      </div>

      {stations.length > 0 && (
        <div className="inline-block border rounded shadow bg-white p-2">
          <table className="table-fixed border-collapse text-[13px]">
            <thead className="sticky top-0 bg-gray-100 z-10">
              <tr>
                <th className="border px-1 py-1 text-center w-[90px] h-[50px]">Stație</th>
                {stations.map(s => (
                  <th key={s} className="border px-1 py-1 text-center w-[70px] h-[32px] truncate">{s}</th>
                ))}
              </tr>
            </thead>
            <tbody>
  {loadingItems ? (
    <tr>
      <td colSpan={stations.length + 1} className="border px-1 py-1 text-center">
        Se încarcă prețurile…
      </td>
    </tr>
  ) : (
    stations.map((from, i) => (
      <tr key={from} className={i % 2 === 0 ? 'bg-white' : 'bg-gray-100'}>
        <td className="border px-1 py-1 text-black font-bold text-center w-[64px] h-[32px] align-middle">{from}</td>
        {stations.map((to, j) => (
          <td key={to} className="border px-1 py-1 text-center w-[64px] h-[32px] align-middle">
            {j <= i ? (
              <div className="w-full h-[50px]"></div>
            ) : (
              <div className="flex flex-col items-center gap-[2px]">
                <div className="flex items-center gap-[4px]">
                  <label className="w-[20px] text-[9px] font-medium text-gray-600 text-center">T</label>
                  <input
                    className="w-[40px] h-[20px] px-1 text-[13px] border border-gray-300 rounded text-center focus:outline-none"
                    value={grid[from]?.[to]?.price}
                    onChange={e => {
                      const val = e.target.value;
                      if (val === '' || /^\d+(\.\d{0,2})?$/.test(val)) {
                        setGrid(prev => ({
                          ...prev,
                          [from]: { ...prev[from], [to]: { ...prev[from][to], price: val } }
                        }));
                      }
                    }}
                  />
                </div>
                <div className="flex items-center gap-[4px]">
                  <label className="w-[20px] text-[9px] font-medium text-gray-600 text-center">T/R</label>
                  <input
                    className="w-[40px] h-[20px] px-1 text-[13px] border border-gray-300 rounded text-center focus:outline-none"
                    value={grid[from]?.[to]?.price_return}
                    onChange={e => {
                      const val = e.target.value;
                      if (val === '' || /^\d+(\.\d{0,2})?$/.test(val)) {
                        setGrid(prev => ({
                          ...prev,
                          [from]: { ...prev[from], [to]: { ...prev[from][to], price_return: val } }
                        }));
                      }
                    }}
                  />
                </div>
              </div>
            )}
          </td>
        ))}
      </tr>
    ))
  )}
</tbody>

          </table>
        </div>
      )}
    </div>
  );
}