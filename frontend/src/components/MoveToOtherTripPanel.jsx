import React, { useState, useEffect, useCallback } from 'react';
import CalendarWrapper from './CalendarWrapper';
import { getBestAvailableSeat } from './reservationLogic';
import SeatMap from './SeatMap';
import ConfirmModal from './ConfirmModal';
import { format } from 'date-fns';



export default function MoveToOtherTripPanel({ onClose, moveToOtherTripData, onMoveSuccess, stops = [] }) {
  const {
    passenger,
    fromSeat,        // dacă l-ai trecut din ReservationPage
    reservation_id,  // ID-ul real al rezervării
    boardAt,
    exitAt,
    originalTime,
    originalRouteId,
    originalDate
  } = moveToOtherTripData || {};

  const [tripReservations, setTripReservations] = useState([]);






  const [selectedDate, setSelectedDate] = useState(() => {
    const d = originalDate ? new Date(originalDate) : new Date();
    return isNaN(d) ? new Date() : d;
  });
  const [routes, setRoutes] = useState([]);
  const [selectedRoute, setSelectedRoute] = useState(null);
  const [selectedStops, setSelectedStops] = useState([]);
  const [selectedStations, setSelectedStations] = useState([]);
  const [selectedHour, setSelectedHour] = useState(null);
  const [newSeats, setNewSeats] = useState([]);
  const [autoSelectedSeat, setAutoSelectedSeat] = useState(null);
  const [toast, setToast] = useState('');

  const [showConfirmModal, setShowConfirmModal] = useState(false);




  const [loadingRoutes, setLoadingRoutes] = useState(false);
  const [loadProgress, setLoadProgress] = useState({ done: 0, total: 0 });




  const toggleSeat = (seat) => {
    setAutoSelectedSeat((prev) => {
      if (prev && prev.id === seat.id) return null; // Deselectează dacă dai click pe același loc
      return seat;
    });
  };

  const [tripVehicles, setTripVehicles] = useState([]);
  const [selectedTripVehicle, setSelectedTripVehicle] = useState(null);

  const getStationIdForName = useCallback(
    (name) => {
      if (!name) return null;
      const match = selectedStations.find((s) => s.name === name);
      return match ? match.station_id : null;
    },
    [selectedStations]
  );

  const getStationNameForId = useCallback(
    (id) => {
      if (id === null || id === undefined) return '';
      const match = selectedStations.find((s) => s.station_id === id);
      return match ? match.name : '';
    },
    [selectedStations]
  );

  const hydrateSeats = useCallback(
    (payload) => {
      if (!Array.isArray(payload)) return payload;

      return payload.map((item) => {
        if (Array.isArray(item?.seats)) {
          return { ...item, seats: hydrateSeats(item.seats) };
        }

        if (!item || typeof item !== 'object') return item;

        const passengers = Array.isArray(item.passengers)
          ? item.passengers.map((p) => ({
            ...p,
            board_at: p.board_at ?? getStationNameForId(p.board_station_id),
            exit_at: p.exit_at ?? getStationNameForId(p.exit_station_id),
          }))
          : [];

        return { ...item, passengers };
      });
    },
    [getStationNameForId]
  );


  // La selectarea unei curse noi:
  const dateStr = format(selectedDate, 'yyyy-MM-dd');
  const board = boardAt;
  const exit = exitAt;









  // Grupează rutele ca la original
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
    'Iași – Dorohoi – Botoșani',
    'Brașov – Botoșani',
    'Rădăuți – Iași'
  ];







  // Încarcă rutele compatibile + progres vizibil
  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        setLoadingRoutes(true);
        setLoadProgress({ done: 0, total: 0 });
        const res = await fetch('/api/routes');
        const all = await res.json();
        if (!Array.isArray(all)) {
          setToast('Eroare la încărcarea rutelor!');
          setLoadingRoutes(false);
          return;
        }
        if (alive) setLoadProgress({ done: 0, total: all.length });
        const compat = [];
        // procesăm secvențial ca să putem actualiza progresul
        for (let i = 0; i < all.length; i++) {
          const route = all[i];
          try {
            const r = await fetch(`/api/routes/${route.id}/stations`);
            const stations = await r.json();
            const ordered = Array.isArray(stations)
              ? [...stations].sort((a, b) => (a.sequence ?? 0) - (b.sequence ?? 0))
              : [];
            const names = ordered.map((s) => s.name);
            const ib = names.indexOf(boardAt);
            const ie = names.indexOf(exitAt);
            const ok = ib !== -1 && ie !== -1 && ib < ie;
            if (ok) compat.push({ ...route, stations: ordered });
          } catch {
            // ignorăm ruta dacă nu putem citi stațiile
          } finally {
            if (alive) setLoadProgress((p) => ({ done: p.done + 1, total: p.total || all.length }));
          }
        }
        if (alive) setRoutes(compat);
      } catch {
        setToast('Eroare la încărcarea rutelor!');
      } finally {
        if (alive) setLoadingRoutes(false);
      }
    })();
    return () => { alive = false; };
  }, [boardAt, exitAt]);


  // Când se schimbă ruta selectată, ia stațiile reale din /api/routes/:id/stations
  useEffect(() => {
    if (!selectedRoute?.id) { setSelectedStops([]); return; }
    fetch(`/api/routes/${selectedRoute.id}/stations`)
      .then(r => r.json())
      .then(rows => {
        const ordered = Array.isArray(rows)
          ? [...rows].sort((a, b) => (a.sequence ?? 0) - (b.sequence ?? 0))
          : [];
        setSelectedStations(ordered);
        const names = ordered.map(s => s.name);
        setSelectedStops(names);
      })
      .catch(() => {
        setSelectedStops([]);
        setSelectedStations([]);
      });
  }, [selectedRoute]);




  //Fetch seats când schimbi vehiculul selectat
  useEffect(() => {
    if (
      selectedTripVehicle &&
      selectedRoute &&
      selectedHour &&
      selectedDate
    ) {
      const dateStr = format(selectedDate, 'yyyy-MM-dd');
      const board = boardAt;
      const exit = exitAt;
      const boardId = getStationIdForName(board);
      const exitId = getStationIdForName(exit);
      if (boardId === null || exitId === null) {
        setNewSeats([]);
        setAutoSelectedSeat(null);
        return;
      }
      fetch(
        `/api/seats/${selectedTripVehicle.vehicle_id}?route_id=${selectedRoute.id}&date=${dateStr}&time=${selectedHour}&board_station_id=${boardId}&exit_station_id=${exitId}`
      )
        .then((res) => res.json())
        .then((seatsData) => {
          const hydrated = hydrateSeats(seatsData);
          setNewSeats(hydrated);
          const bestSeat = getBestAvailableSeat(hydrated, board, exit, selectedStops);
          setAutoSelectedSeat(bestSeat);
        })
        .catch(() => {
          setToast('Eroare la încărcarea locurilor!');
          setNewSeats([]);
          setAutoSelectedSeat(null);
        });
    }
  }, [selectedTripVehicle, selectedRoute, selectedHour, selectedDate, boardAt, exitAt, getStationIdForName, hydrateSeats, selectedStops]);








  // Fetch seats după alegerea datei, rutei și orei
  useEffect(() => {
    if (!selectedRoute || !selectedHour || !selectedDate) {
      setNewSeats([]);
      setAutoSelectedSeat(null);
      setTripVehicles([]);
      setSelectedTripVehicle(null);
      return;
    }
    // Folosim format din date-fns ca să avem data în local time (yyyy-MM-dd)
    const dateStr = format(selectedDate, 'yyyy-MM-dd');
    const board = boardAt;
    const exit = exitAt;
    const boardId = getStationIdForName(board);
    const exitId = getStationIdForName(exit);
    if (boardId === null || exitId === null) {
      setNewSeats([]);
      setAutoSelectedSeat(null);
      setTripVehicles([]);
      setSelectedTripVehicle(null);
      return;
    }

    // ⚠️ CAUTĂ un trip corespunzător pentru combinația selectată (riscă să nu existe încă)
    fetch(
      `/api/trips/find?route_id=${selectedRoute.id}&date=${dateStr}&time=${selectedHour}`
    )
      .then((res) => res.json())
      .then((tripData) => {
        console.log('TRIP DATA', tripData); // <<--- AICI!
        if (!tripData?.id) {
          setNewSeats([]);
          setAutoSelectedSeat(null);
          setToast('Nu există cursă programată!');
          setTripVehicles([]);
          setSelectedTripVehicle(null);
          return;
        }
        // Fetch toate vehiculele asociate trip-ului (primar și dubluri)
        fetch(`/api/seats?route_id=${selectedRoute.id}&date=${dateStr}&time=${selectedHour}&board_station_id=${boardId}&exit_station_id=${exitId}`)
          .then(res => res.json())
          .then(vehiclesData => {
            console.log('TRIP VEHICLES', vehiclesData); // <<--- AICI!
            const hydrated = hydrateSeats(vehiclesData);
            setTripVehicles(hydrated);
            // Selectează primul vehicul by default
            if (hydrated.length > 0) {
              setSelectedTripVehicle(hydrated[0]);
            }
          })
          .catch(() => {
            setTripVehicles([]);
            setSelectedTripVehicle(null);
            setToast('Eroare la încărcarea vehiculelor!');
          });
      })
      .catch(() => {
        setToast('Eroare la identificarea cursei!');
        setNewSeats([]);
        setAutoSelectedSeat(null);
        setTripVehicles([]);
        setSelectedTripVehicle(null);
      });
  }, [selectedRoute, selectedHour, selectedDate, boardAt, exitAt, getStationIdForName, hydrateSeats]);

  // Confirmă mutarea (trimite la backend)
  const handleConfirmMove = async () => {
    if (!autoSelectedSeat || !selectedRoute || !selectedHour || !selectedDate) {
      setToast('Selectează dată, rută, oră și loc!');
      return;
    }
    const dateStr = format(selectedDate, 'yyyy-MM-dd');
    const boardId = getStationIdForName(boardAt);
    const exitId = getStationIdForName(exitAt);
    if (boardId === null || exitId === null) {
      setToast('Stațiile selectate nu sunt disponibile pe această rută.');
      return;
    }

    // Identifică trip-ul nou
    const tripRes = await fetch(
      `/api/trips/find?route_id=${selectedRoute.id}&date=${dateStr}&time=${selectedHour}`
    );
    const tripData = await tripRes.json();
    if (!tripData?.id) {
      setToast('Nu există această cursă!');
      return;
    }

    // ⚡️ DEBUG: vezi exact ce date trimiți la mutare!
    const payload = {
      old_reservation_id: reservation_id,   // cel corect, transmis din ReservationPage

      new_trip_id: tripData.id,
      new_seat_id: autoSelectedSeat.id,
      board_station_id: boardId,
      exit_station_id: exitId,
      phone: passenger?.phone,
      name: passenger?.name,
    };
    console.log('[MoveToOtherTripPanel] Trimit la backend:', payload);


    try {
      const res = await fetch('/api/reservations/moveToOtherTrip', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      // ⚡️ DEBUG: vezi exact ce răspuns primești de la backend!
      let data;
      try {
        data = await res.json();
      } catch (err) {
        data = { error: 'Nu e JSON răspunsul!' };
      }
      console.log('[MoveToOtherTripPanel] Răspuns backend:', data);


      if (!res.ok) {
        setToast(data.error || 'Eroare la mutare!');
        return;
      }
      // 1) Afișează toast imediat
      window.dispatchEvent(new CustomEvent("toast", {
        detail: { message: 'Rezervare mutată cu succes!', type: 'success' }
      }));


      // 1) închide panel-ul IMEDIAT
      onClose();

      // 2) apoi notifică părintelui să reîncarce diagrama pentru cursa NOUĂ
      onMoveSuccess?.({
        tripId: tripData.id,
        vehicleId: tripData.vehicle_id,
        routeId: selectedRoute.id,
        date: selectedDate,
        hour: selectedHour
      });


    } catch (err) {
      window.dispatchEvent(new CustomEvent("toast", {
        detail: { message: err.message || 'Eroare la mutare!', type: 'error' }
      }));
    }
  };


  // Afișare UI rute/oră/locuri
  const renderRoutesGroup = (title, orderedNames) => {
    const filteredRoutes = orderedNames
      .map((name) => routes.find((r) => r.name === name))
      .filter(Boolean);



    return (
      <div className="mb-4">
        <h3 className="text-sm font-semibold text-gray-700 mb-1">{title}</h3>
        <div className="flex flex-wrap gap-2">
          {loadingRoutes && (
            <div className="mb-2 flex items-center gap-2 text-sm text-gray-600">
              <div className="h-4 w-4 rounded-full border-2 border-gray-300 border-t-transparent animate-spin" />
              <span>
                Se încarcă rutele compatibile… {loadProgress.done}/{loadProgress.total || '—'}
              </span>
            </div>
          )}
          {filteredRoutes.map((route) => (
            <button
              key={route.id}
              onClick={() => setSelectedRoute(route)}
              className={`px-3 py-1 rounded border text-sm ${selectedRoute?.id === route.id
                ? 'bg-blue-500 text-white border-blue-600'
                : 'bg-gray-100 hover:bg-gray-200 border-gray-300 text-gray-800'
                }`}
            >
              {route.name}
            </button>
          ))}
        </div>
      </div>
    );
  };

  const renderHours = () => {
    if (!selectedRoute || !Array.isArray(selectedRoute.schedules) || selectedRoute.schedules.length === 0) return null;







    return (
      <div>
        <h3 className="text-sm font-semibold text-gray-700 mb-1">
          Ore disponibile
        </h3>
        <div className="flex flex-wrap gap-2">

          {selectedRoute.schedules
            .filter(({ departure }) => {
              // originalDate e acum un Date real
              const orig = new Date(originalDate);
              const isSameRoute = selectedRoute.id === originalRouteId;
              const isSameDate =
                selectedDate.getFullYear() === orig.getFullYear() &&
                selectedDate.getMonth() === orig.getMonth() &&
                selectedDate.getDate() === orig.getDate();

              // excludem doar dacă ruta, data și ora coincid
              if (isSameRoute && isSameDate && departure === originalTime) {
                return false;
              }
              return true;
            })
            .map(({ departure, themeColor, operatorId }) => (
              <button
                key={departure}
                onClick={() => setSelectedHour(departure)}
                className={`
                px-2 py-0 rounded border text-sm
                ${selectedHour === departure
                    ? 'bg-blue-500 text-white border-blue-600'
                    : 'bg-gray-100 hover:bg-gray-200 border-gray-300 text-gray-800'
                  }
              `}
                style={{
                  backgroundColor: `${themeColor}20`,
                  borderColor: themeColor
                }}
              >
                {departure}
              </button>
            ))}
        </div>
      </div>
    );
  };

  // MoveToOtherTripPanel.jsx
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
      <div className="bg-white rounded-xl shadow-2xl w-full max-w-3xl p-0 overflow-y-auto max-h-[90vh] relative">
        {/* Header cu titlu și buton de închidere */}
        <div className="p-4 border-b flex justify-between items-center">
          <h2 className="text-xl font-bold text-gray-800">🔄 Mută pe altă cursă</h2>
          <button
            className="text-gray-600 hover:text-black text-2xl"
            onClick={onClose}
          >
            ✕
          </button>
        </div>
        {/* Conținutul modalului */}
        <div className="p-6 text-gray-700 space-y-4">
          <CalendarWrapper
            selectedDate={selectedDate}
            setSelectedDate={setSelectedDate}
          />

          {renderRoutesGroup('Tururi', turOrder)}
          {renderRoutesGroup('Retururi', returOrder)}
          {renderHours()}


          {tripVehicles.length > 1 && (
            <div style={{ display: 'flex', gap: 8, marginBottom: 10 }}>
              {tripVehicles.map((tv, idx) => (
                <button
                  key={tv.vehicle_id}
                  className={tv.vehicle_id === selectedTripVehicle?.vehicle_id ? 'active' : ''}
                  onClick={() => setSelectedTripVehicle(tv)}
                  style={{
                    padding: 8,
                    border: tv.vehicle_id === selectedTripVehicle?.vehicle_id ? '2px solid #0af' : '1px solid #ccc',
                    background: tv.is_primary ? '#e3f5ff' : '#f9f9f9',
                    fontWeight: tv.is_primary ? 'bold' : 'normal'
                  }}
                >
                  {tv.vehicle_name || tv.name || `Vehicul ${idx + 1}`} {tv.is_primary ? "(Principal)" : "(Dublură)"}
                </button>
              ))}
            </div>
          )}



          {selectedHour && newSeats.length > 0 && (
            <div className="mt-6 flex flex-col items-center">
              <h3 className="text-base font-semibold text-gray-700 mb-2">Alege locul:</h3>
              <SeatMap
                seats={selectedTripVehicle?.seats || []}
                stops={selectedStops}               // <— TRIMITE stops către SeatMap
                selectedSeat={autoSelectedSeat}
                selectedSeats={autoSelectedSeat ? [autoSelectedSeat] : []}
                setSelectedSeats={(arr) => setAutoSelectedSeat(arr[0] || null)}
                toggleSeat={toggleSeat}
                selectedRoute={selectedRoute}
                boardAt={boardAt}
                exitAt={exitAt}
                readOnly={false}
              />
              {autoSelectedSeat && (
                <div className="mt-2 text-green-600 text-base">
                  Loc selectat: {autoSelectedSeat.label}
                </div>
              )}
            </div>
          )}

          <div className="flex justify-end mt-8">
            <button
              className="bg-green-600 text-white px-8 py-2 rounded-lg hover:bg-green-700 text-lg font-semibold shadow"
              onClick={() => setShowConfirmModal(true)}
              disabled={!autoSelectedSeat || !selectedHour || !selectedRoute}
            >
              Mută rezervarea
            </button>
          </div>
          {toast && (
            <div className="mt-4 text-center text-red-600 font-semibold">{toast}</div>
          )}
        </div>
      </div>


      <ConfirmModal
        show={showConfirmModal}
        title="Confirmă mutarea"
        message="Ești sigur că vrei să muți această rezervare pe noua cursă și loc?"
        confirmText="Mută"
        cancelText="Renunță"
        onConfirm={async () => {
          setShowConfirmModal(false);
          // Apelăm funcția efectivă de mutare
          await handleConfirmMove();
        }}
        onCancel={() => setShowConfirmModal(false)}
      />






    </div>
  );


}
