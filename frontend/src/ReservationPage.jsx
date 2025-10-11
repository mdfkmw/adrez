import React, { useState, useEffect, useMemo, useCallback } from 'react';
import Calendar from 'react-calendar';
import { format, addDays } from 'date-fns';
import { ro } from 'date-fns/locale';
import 'react-calendar/dist/Calendar.css';
import Select from 'react-select';
import Toast from './components/Toast';
import PassengerPopup from './components/PassengerPopup';
import MultiPassengerPopup from './components/MultiPassengerPopup';
import RouteSelector from './components/RouteSelector';
import HourSelector from './components/HourSelector';
import VehicleSelector from './components/VehicleSelector';
import SeatMap from './components/SeatMap';
import PassengerForm from './components/PassengerForm';
import { isPassengerValid } from './components/utils/validation';

import MoveToOtherTripPanel from './components/MoveToOtherTripPanel';
import CalendarWrapper from './components/CalendarWrapper';
import AddVehicleModal from './components/AddVehicleModal';
import ConfirmModal from './components/ConfirmModal';








export default function ReservationPage() {
  // 📅 Starea pentru data selectată în calendar
  const [selectedDate, setSelectedDate] = useState(new Date());
  // --- Lista stațiilor normalizate pentru ruta selectată ---
  const [routeStations, setRouteStations] = useState([]);
  // 🚍 Ruta selectată de utilizator
  const [selectedRoute, setSelectedRoute] = useState(null);
  // Derivăm o singură dată lista de nume stații din routeStations
  const stops = useMemo(() => routeStations.map(s => s.name), [routeStations]);
  const stationIdByName = useMemo(() => {
    const map = new Map();
    for (const st of routeStations) {
      map.set(st.name, st.station_id);
    }
    return map;
  }, [routeStations]);
  const stationNameById = useMemo(() => {
    const map = new Map();
    for (const st of routeStations) {
      map.set(String(st.station_id), st.name);
    }
    return map;
  }, [routeStations]);

  const getStationIdByName = useCallback(
    (name) => {
      if (!name) return null;
      return stationIdByName.get(name) ?? null;
    },
    [stationIdByName]
  );

  const getStationNameById = useCallback(
    (stationId) => {
      if (stationId === null || stationId === undefined) return '';
      return stationNameById.get(String(stationId)) ?? '';
    },
    [stationNameById]
  );

  const hydrateSeatPayload = useCallback(
    (payload) => {
      if (!Array.isArray(payload)) return payload;

      return payload.map((item) => {
        if (item && Array.isArray(item.seats)) {
          return { ...item, seats: hydrateSeatPayload(item.seats) };
        }

        if (!item || typeof item !== 'object') {
          return item;
        }

        const passengers = Array.isArray(item.passengers)
          ? item.passengers.map((p) => ({
            ...p,
            board_at: p.board_at ?? getStationNameById(p.board_station_id),
            exit_at: p.exit_at ?? getStationNameById(p.exit_station_id),
          }))
          : [];

        return { ...item, passengers };
      });
    },
    [getStationNameById]
  );

  const handleConflictInfoUpdate = useCallback(
    (infos) => {
      const enriched = Array.isArray(infos)
        ? infos.map((info) => ({
          ...info,
          board_at: getStationNameById(info.board_station_id),
          exit_at: getStationNameById(info.exit_station_id),
        }))
        : [];
      setConflictInfo(enriched);
    },
    [getStationNameById]
  );
  // ⏰ Ora selectată pentru cursa aleasă
  const [selectedHour, setSelectedHour] = useState(null);
  // 💺 Locurile selectate în diagrama autobuzului
  const [selectedSeats, setSelectedSeats] = useState([]);
  // 🧭 Toate locurile disponibile pentru vehiculul curent
  const [seats, setSeats] = useState([]);
  // 🛣️ Lista rutelor disponibile din baza de date
  const [routesList, setRoutesList] = useState([]);






  // 👥 Obiect care conține datele fiecărui pasager selectat
  const [passengersData, setPassengersData] = useState({});
  // 💾 Indicator pentru afișarea spinner-ului la salvare
  const [isSaving, setIsSaving] = useState(false);
  const [shake, setShake] = useState(false); // efect vizual la erori
  // ✅ Mesaj de confirmare sau eroare la salvare
  const [saveMessage, setSaveMessage] = useState('');
  // 🔔 Textul notificării (toast)
  const [toastMessage, setToastMessage] = useState('');
  // 🔔 Tipul notificării (info, success, error)
  const [toastType, setToastType] = useState('info');

  // ✏️ Control pentru afișarea/ascunderea observațiilor per loc
  const [notesVisibility, setNotesVisibility] = useState({});
  // 🚐 Control pentru afișarea popup-ului de alegere vehicul
  const [showVehiclePopup, setShowVehiclePopup] = useState(false);
  // 🚌 Lista vehiculelor disponibile încărcată din backend
  const [availableVehicles, setAvailableVehicles] = useState([]);
  // ℹ️ Info despre vehiculul atribuit (nume și nr. înmatriculare)
  const [vehicleInfo, setVehicleInfo] = useState(null);
  // 🗺️ ID-ul cursei (trip) curente pentru cereri precise
  const [tripId, setTripId] = useState(null);
  const [selectedTrip, setSelectedTrip] = useState(null);
  const [moveSourceSeat, setMoveSourceSeat] = useState(null);

  const [popupPassenger, setPopupPassenger] = useState(null);
  const [popupSeat, setPopupSeat] = useState(null);
  const [popupPosition, setPopupPosition] = useState(null);




  const [multiPassengerOptions, setMultiPassengerOptions] = useState(null);
  const [editingReservationId, setEditingReservationId] = useState(null);
  const [pricePerSeat, setPricePerSeat] = useState({});

  const [passengers, setPassengers] = useState([]);
  const [showMoveToOtherTrip, setShowMoveToOtherTrip] = useState(false);
  const [moveToOtherTripData, setMoveToOtherTripData] = useState(null);





  const [tripVehicles, setTripVehicles] = useState([]);
  const [activeTv, setActiveTv] = useState(null);
  const [showAddVeh, setShowAddVeh] = useState(false);
  const [confirmTvToDelete, setConfirmTvToDelete] = useState(null);



  // stocăm lista de conflicte (acum array) venit din backend
  const [conflictInfo, setConflictInfo] = useState([]);
  // control pentru ConfirmModal
  const [showConflictModal, setShowConflictModal] = useState(false);
  // în ReservationPage.jsx, înainte de JSX-ul modalului, adaugă:

  //Dacă conflictCount === 1 „Mai există 1 rezervare conflictuală (în aceeași zi):”
  //Dacă conflictCount > 1, va afișa: „Mai există 3 rezervări conflictuale (în aceeași zi):”
  const conflictCount = conflictInfo?.length ?? 0;
  const rezervareWord = conflictCount === 1
    ? 'rezervare conflictuală'
    : 'rezervări conflictuale';








  // Taburi masini
  const tabs = tripVehicles;


  //copiere datele primului pasager la ceilalti pasageri
  // Unde ai logica de copiere date pasager principal
  // After: use JSON deep‐clone so mutations don’t bleed through
  const handleCopyPassengerData = () => {
    if (selectedSeats.length < 2) return;
    const firstSeatId = selectedSeats[0].id;
    const firstPassenger = passengersData[firstSeatId];
    if (!firstPassenger) return;

    setPassengersData(prev => {
      const updated = { ...prev };
      // facem deep clone ca să nu mutăm referințe mutabile
      const baseCopy = JSON.parse(JSON.stringify(firstPassenger));
      // extragem și eliminăm orice câmp de reducere vechi
      const { discount, discount_type_id, ...rest } = baseCopy;
      selectedSeats.slice(1).forEach(seat => {
        updated[seat.id] = {
          ...rest,
          // resetăm reducerea noului pasager
          discount_type_id: null
        };
      });
      return updated;
    });
  };












  //calcul automat afisare pret in functie de reducere
  function calculeazaPretCuReducere(pret, discount) {
    if (!pret || isNaN(pret)) return pret;
    switch (discount) {
      case "pensionar":
      case "copil":
        return pret / 2;
      case "veteran":
      case "das":
      case "vip":
        return 0;
      default:
        return pret;
    }
  }







  const [blacklistInfo, setBlacklistInfo] = useState(null);
  const [showBlacklistModal, setShowBlacklistModal] = useState(false);



  //loader sa apara intre schimbatul orelor
  const [isLoadingSeats, setIsLoadingSeats] = useState(false);






  const handleAddVehicle = () => {
    // momentan inactiv, se poate extinde
    setToastMessage('Funcționalitate neimplementată');
    setToastType('info');
    setTimeout(() => setToastMessage(''), 3000);
  };





  // reducerile valabile pentru ruta + oră
  const [routeDiscounts, setRouteDiscounts] = useState([]);
  //reduceri pe categorii
  const [pricingCategories, setPricingCategories] = useState([]);




  // fetch reduceri de fiecare dată când ruta sau ora se schimbă
  useEffect(() => {
    // validăm că avem un obiect route și un hour selectate
    if (!selectedRoute?.id || !selectedHour) {
      setRouteDiscounts([]);
      return;
    }
    fetch(
      `/api/routes/${selectedRoute.id}/discounts?time=${selectedHour}`
    )
      .then(res => (res.ok ? res.json() : []))
      .then(setRouteDiscounts)
      .catch(() => setRouteDiscounts([]));

  }, [selectedRoute, selectedHour]);

  // --- Când se schimbă ruta, încarcă stațiile normalizate ---
  useEffect(() => {
    if (!selectedRoute?.id) { setRouteStations([]); return; }
    (async () => {
      try {
        const res = await fetch(`/api/routes/${selectedRoute.id}/stations`);
        const data = await res.json();
        if (Array.isArray(data)) {
          data.sort((a, b) => (a.sequence ?? 0) - (b.sequence ?? 0));
          setRouteStations(data);
        } else setRouteStations([]);
      } catch (err) {
        console.error('Eroare la /api/routes/:id/stations', err);
        setRouteStations([]);
      }
    })();
  }, [selectedRoute?.id]);


  //fetch pret categorii
  useEffect(() => {
    fetch('/api/pricing-categories')
      .then(r => r.json())
      .then(setPricingCategories)
      .catch(() => setPricingCategories([]));
  }, []);











  // Calculează totalul de plată pentru pasagerii selectați (aplică reducerile)
  const getTotalToPay = () => {
    let total = 0;
    selectedSeats.forEach(seat => {
      const price = pricePerSeat[seat.id];
      if (typeof price !== 'number') return;

      const discId = passengersData[seat.id]?.discount_type_id;
      const disc = routeDiscounts.find(d => d.id === discId);

      if (!disc) {
        total += price;
      } else {
        const v = parseFloat(disc.discount_value);
        let raw = disc.discount_type === 'percent'
          ? price * (1 - v / 100)
          : price - v;
        total += Math.max(raw, 0);
      }
    });
    // total final nu poate fi negativ
    return Number(Math.max(total, 0).toFixed(2));
  };








  const handlePaymentChange = (seatId, method) => {
    setPassengers((prev) =>
      prev.map((p) =>
        p.seat_id === seatId ? { ...p, payment_method: method } : p
      )
    );
  };

  const handleTransactionChange = (seatId, value) => {
    setPassengers((prev) =>
      prev.map((p) =>
        p.seat_id === seatId ? { ...p, transaction_id: value } : p
      )
    );
  };


  const fetchPrice = async (seatId, from, to) => {
    // fără oră, nu cerem preţ
    if (!selectedHour) return;
    // dacă nu avem categorii încă, așteptăm
    if (pricingCategories.length === 0) return;

    // preia categoria curentă pentru acest seat sau default prima categorie
    const categoryId = passengersData[seatId]?.category_id ?? pricingCategories[0].id;
    if (!from || !to || !selectedRoute?.id || !categoryId) return;


    try {
const fromId = getStationIdByName(from);
const toId   = getStationIdByName(to);
if (fromId === null || toId === null) {
  setPricePerSeat(prev => ({ ...prev, [seatId]: 'N/A' }));
  return;
}

const qs = new URLSearchParams({
  route_id: String(selectedRoute.id),
  from_station_id: String(fromId),
  to_station_id: String(toId),
  category: String(categoryId),
  date: format(selectedDate, 'yyyy-MM-dd')
});

const res = await fetch(`http://localhost:5000/api/routes/price?${qs.toString()}`);

      if (!res.ok) {
        console.error('fetchPrice HTTP error', res.status);
        setPricePerSeat(prev => ({ ...prev, [seatId]: 'N/A' }));
        return;
      }
      const { price, price_list_id, pricing_category_id } = await res.json();
      // Salvează preț și ID-uri pentru payload
      // ─── persistăm identificatorul listei şi la nivel global ───
      setSelectedPriceListId(curr => curr ?? price_list_id);

      setPassengersData(prev => ({
        ...prev,
        [seatId]: {
          ...prev[seatId],
          price: parseFloat(price),
          price_list_id,
          category_id: pricing_category_id
        }
      }));
      setPricePerSeat(prev => ({ ...prev, [seatId]: parseFloat(price) }));
    } catch (err) {
      console.error('Eroare la fetchPrice:', err);
      setPricePerSeat(prev => ({ ...prev, [seatId]: 'N/A' }));
    }
  };




























  const isSeatFullyOccupiedViaSegments = (seat) => {
    const stops = routeStations.map(s => s.name);
    if (!seat.passengers || stops.length < 2) return false;

    const occupancy = Array(stops.length - 1).fill(false);
    const normalize = (s) => s.trim().toLowerCase();

    for (const p of seat.passengers) {
      const i = stops.findIndex((s) => normalize(s) === normalize(p.board_at));
      const j = stops.findIndex((s) => normalize(s) === normalize(p.exit_at));
      if (i !== -1 && j !== -1 && i < j) {
        for (let k = i; k < j; k++) {
          occupancy[k] = true;
        }
      }
    }

    return occupancy.every(Boolean);
  };


  const resetDefaultSeat = () => {
    // nu facem nimic dacă nu există o oră selectată
    if (!selectedHour) return;
    if (!selectedRoute || !selectedDate || !seats.length) return;

    const stops = routeStations.map(s => s.name);
    const board_at = stops[0];
    const exit_at = stops[stops.length - 1];

    const newDefaultSeat = findAvailableSeatForSegment(board_at, exit_at);
    if (!newDefaultSeat) return;


    setSelectedSeats([newDefaultSeat]);
    setPassengersData({
      [newDefaultSeat.id]: {
        name: '',
        phone: '',
        board_at,
        exit_at,
        observations: '',
        payment_method: 'none',
      },
    });

    // 🔥 Apelează prețul imediat
    fetchPrice(newDefaultSeat.id, board_at, exit_at);


  };


  const handleMovePassenger = async (sourceSeat, targetSeat) => {
    const sourcePassenger = sourceSeat.passengers?.[0];
    if (!sourcePassenger || !tripId) return;

    const normalize = (s) => s.trim().toLowerCase();
    const stops = routeStations.map(s => s.name);

    const boardIndex = stops.findIndex((s) => normalize(s) === normalize(sourcePassenger.board_at));
    const exitIndex = stops.findIndex((s) => normalize(s) === normalize(sourcePassenger.exit_at));

    if (boardIndex === -1 || exitIndex === -1 || boardIndex >= exitIndex) return;

    const existingPassengers = targetSeat.passengers || [];
    const hasOverlap = existingPassengers.some((p) => {
      const pBoard = stops.findIndex((s) => normalize(s) === normalize(p.board_at));
      const pExit = stops.findIndex((s) => normalize(s) === normalize(p.exit_at));
      return !(exitIndex <= pBoard || boardIndex >= pExit);
    });

    if (hasOverlap) return;

    try {
      await fetch('http://localhost:5000/api/reservations/move', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          trip_id: tripId,
          from_seat_id: sourceSeat.id,
          to_seat_id: targetSeat.id,
          phone: sourcePassenger.phone,
          board_station_id: sourcePassenger.board_station_id,
          exit_station_id: sourcePassenger.exit_station_id,
        }),
      });

      // determină ce vehicul e activ (principal sau dublură)
      const tv = tripVehicles.find(tv => tv.trip_vehicle_id === activeTv);
      const vehicleId = tv ? tv.vehicle_id : selectedTrip.vehicle_id;
      const firstStopId = getStationIdByName(stops[0]);
      const lastStopId = getStationIdByName(stops.slice(-1)[0]);
      const refreshed = await fetch(
        `http://localhost:5000/api/seats/${vehicleId}` +
        `?route_id=${selectedRoute.id}` +
        `&date=${format(selectedDate, 'yyyy-MM-dd')}` +
        `&time=${selectedHour}` +
        `&board_station_id=${firstStopId}` +
        `&exit_station_id=${lastStopId}`
      );
      const updatedSeats = await refreshed.json();
      setSeats(hydrateSeatPayload(updatedSeats));

      resetDefaultSeat();
    } catch (err) {
      console.error('Eroare la mutare:', err);
    } finally {
      setMoveSourceSeat(null);
    }
  };


  const handleEditPassenger = (passenger, seat) => {


    // Setăm ID-ul rezervării pentru a ști că suntem în mod editare
    setEditingReservationId(passenger.reservation_id);

    // Căutăm locul din seats
    const newSeat = seats.find((s) => s.id === seat.id);
    if (!newSeat) return;
    console.log('handleEditPassenger – selecting:', newSeat.label);
    // Selectăm doar acest loc

    setSelectedSeats([newSeat]);

    // Completăm datele în formular
    setPassengersData({
      [newSeat.id]: {
        name: passenger.name,
        phone: passenger.phone,
        board_at: passenger.board_at,
        exit_at: passenger.exit_at,
        observations: passenger.observations || '',
        reservation_id: passenger.reservation_id,
      },
    });

    // Închidem toate popupurile
    setPopupPassenger(null);
    setPopupSeat(null);
    setMultiPassengerOptions(null);
  };


  const findAvailableSeatForSegment = (board_at, exit_at) => {
    const normalize = (s) => s?.trim().toLowerCase();
    const boardIndex = stops?.findIndex((s) => normalize(s) === normalize(board_at));
    const exitIndex = stops?.findIndex((s) => normalize(s) === normalize(exit_at));

    if (boardIndex === -1 || exitIndex === -1 || boardIndex >= exitIndex) {
      console.warn('⚠️ Segment invalid');
      return null;
    }

    const sortedSeats = [...seats].sort((a, b) => parseInt(a.label) - parseInt(b.label));
    const partialMatches = [];
    const fullMatches = [];

    for (const seat of sortedSeats) {
      if (seat.label.toLowerCase().includes('șofer')) continue;
      if (seat.status === 'full') continue; // 🚫 Ignorăm locurile ocupate complet

      // *** Doar pasageri activi ***
      const passengers = Array.isArray(seat.passengers)
        ? seat.passengers.filter(p => p.status === 'active')
        : [];

      let hasConflict = false;

      for (const r of passengers) {
        const rBoard = stops.findIndex((s) => normalize(s) === normalize(r.board_at));
        const rExit = stops.findIndex((s) => normalize(s) === normalize(r.exit_at));
        if (rBoard === -1 || rExit === -1) continue;

        const overlap = !(exitIndex <= rBoard || boardIndex >= rExit);
        if (overlap) {
          hasConflict = true;
          break;
        }
      }

      if (!hasConflict) {
        if (passengers.length === 0) {
          fullMatches.push(seat);
        } else {
          partialMatches.push(seat);
        }
      }
    }

    return partialMatches[0] || fullMatches[0] || null;
  };


  const checkSegmentOverlap = (existing, board_at, exit_at, stops) => {
    const normalize = (s) => s?.trim().toLowerCase();
    const boardIndex = stops.findIndex((s) => normalize(s) === normalize(board_at));
    const exitIndex = stops.findIndex((s) => normalize(s) === normalize(exit_at));
    const rBoardIndex = stops.findIndex((s) => normalize(s) === normalize(existing.board_at));
    const rExitIndex = stops.findIndex((s) => normalize(s) === normalize(existing.exit_at));

    return !(exitIndex <= rBoardIndex || boardIndex >= rExitIndex);
  };


  // 🔄 Funcție care încarcă vehiculele disponibile din backend și deschide popup-ul de alegere




  useEffect(() => {
    const handleGlobalClick = (e) => {
      // dacă ai popup activ
      if (popupPassenger || multiPassengerOptions) {
        const clickedInsidePopup = e.target.closest('.popup-container');
        const clickedOnSeat = e.target.closest('[data-seat-id]');

        // dacă nu e click pe popup sau pe un loc
        if (!clickedInsidePopup && !clickedOnSeat) {
          setPopupPassenger(null);
          setPopupSeat(null);
          setMultiPassengerOptions(null);
        }
      }
    };

    window.addEventListener('click', handleGlobalClick);
    return () => window.removeEventListener('click', handleGlobalClick);
  }, [popupPassenger, multiPassengerOptions]);


  // ═════ Încărcare rute pentru data selectată + sincronizare selectedRoute ═════
  useEffect(() => {
    const dateStr = format(selectedDate, 'yyyy-MM-dd');
    fetch(`http://localhost:5000/api/routes?date=${dateStr}`)
      .then((res) => {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then((data) => {
        setRoutesList(data);
        // dacă aveai deja o rută selectată,
        // actualizeaz-o cu versiunea nouă din 'data'
        if (selectedRoute) {
          const updated = data.find((r) => r.id === selectedRoute.id) || null;
          setSelectedRoute(updated);
        }
      })
      .catch((err) =>
        console.error('Eroare la încărcarea rutelor pentru', dateStr, err)
      );
  }, [selectedDate]);











  // ✅ Marchează / demarchează locurile selectate și actualizează pasagerii
  const toggleSeat = (seat) => {


    console.log('toggleSeat – before setSelectedSeats:', seat.label);


    setSelectedSeats((prev) =>
      prev.find((s) => s.id === seat.id)
        ? prev.filter((s) => s.id !== seat.id)
        : [...prev, seat]
    );

    setPassengersData((prev) => {
      const exists = !!prev[seat.id];
      if (exists) {
        const copy = { ...prev };
        delete copy[seat.id];
        return copy;
      } else {
        const stops = routeStations.map(s => s.name);
        const reservedSegment = seat.passenger
          ? {
            board: seat.passenger.board_at,
            exit: seat.passenger.exit_at,
          }
          : null;

        let board_at = stops[0];
        let exit_at = stops[stops.length - 1];

        if (reservedSegment && seat.status === 'partial') {
          const reservedStart = stops.indexOf(reservedSegment.board);
          const reservedEnd = stops.indexOf(reservedSegment.exit);

          for (let i = 0; i < stops.length - 1; i++) {
            const currentStart = i;
            const currentEnd = i + 1;

            // Dacă segmentul actual NU se suprapune cu rezervarea
            if (
              currentEnd <= reservedStart ||
              currentStart >= reservedEnd
            ) {
              board_at = stops[currentStart];
              exit_at = stops[currentEnd];
              break;
            }
          }
        }

        return {
          ...prev,
          [seat.id]: {
            name: '',
            phone: '',
            board_at,
            exit_at,
            observations: '',
            payment_method: 'none',
          },
        };
      }
    });
  };




  useEffect(() => {
    selectedSeats.forEach(seat => {
      const data = passengersData[seat.id];
      // Dacă există datele, și nu avem deja preț pentru seat-ul acesta, îl cerem
      if (
        data &&
        data.board_at &&
        data.exit_at &&
        (pricePerSeat[seat.id] === undefined || pricePerSeat[seat.id] === null)
      ) {
        fetchPrice(seat.id, data.board_at, data.exit_at);
      }
    });
  }, [selectedSeats, passengersData, pricePerSeat]);


  const [selectedPricingCategoryId, setSelectedPricingCategoryId] = useState( /* valoare inițială */);
  const [selectedPriceListId, setSelectedPriceListId] = useState( /* valoare inițială */);

  // 💾 Trimite rezervarea către backend și afișează notificare + reîncarcă locurile
  const submitReservation = () => {
    setIsSaving(true);
    setToastMessage('Se salvează rezervarea...');
    setToastType('info');

    // ─── determinăm price_list_id ───
    const derivedListId = selectedPriceListId || (passengersData[selectedSeats[0]?.id]?.price_list_id ?? null);

    let passengersPayload;
    try {
      passengersPayload = selectedSeats.map((seat) => {
        const d = passengersData[seat.id];
        const boardStationId = getStationIdByName(d.board_at);
        const exitStationId = getStationIdByName(d.exit_at);
        if (boardStationId === null || exitStationId === null) {
          throw new Error('Stațiile selectate nu sunt valide pentru această rută.');
        }

        return {
          seat_id: seat.id,
          reservation_id: d.reservation_id || null,
          person_id: d.person_id || null,
          name: d.name,
          phone: d.phone,
          board_station_id: boardStationId,
          exit_station_id: exitStationId,
          price_list_id: d.price_list_id || derivedListId,
          category_id: d.category_id ?? pricingCategories[0].id,
          observations: d.observations || '',
          discount_type_id: d.discount_type_id || null,
          price: pricePerSeat[seat.id],
          payment_method: d.payment_method || 'none',
          transaction_id: d.transaction_id || null
        };
      });
    } catch (err) {
      setToastMessage(err.message);
      setToastType('error');
      setIsSaving(false);
      setTimeout(() => setToastMessage(''), 3000);
      return;
    }

    const payload = {
      date: format(selectedDate, 'yyyy-MM-dd'),
      time: selectedHour,
      route_id: selectedRoute.id,
      vehicle_id: selectedTrip.vehicle_id,
      pricing_category_id: selectedPricingCategoryId,
      price_list_id: derivedListId,
      passengers: passengersPayload,
    };
    console.log('payload:', payload);

    fetch('http://localhost:5000/api/reservations', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    })
      .then(async (res) => {
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || 'Eroare la salvare');
        setSelectedSeats([]);
        setPassengersData({});
        setToastMessage('Rezervare salvată cu succes ✅');
        setToastType('success');
        setTimeout(() => {
          setToastMessage('');
          setIsSaving(false);
        }, 3000);
        return data;
      })
      .then(() => {
        // reîncarcă seat-map
        const currentVehId =
          activeTv === 'main'
            ? selectedTrip.vehicle_id
            : tripVehicles.find(tv => tv.trip_vehicle_id === activeTv)?.vehicle_id;
        const firstStopId = getStationIdByName(stops[0]);
        const lastStopId = getStationIdByName(stops.slice(-1)[0]);
        return fetch(
          `http://localhost:5000/api/seats/${currentVehId}` +
          `?route_id=${selectedRoute.id}` +
          `&date=${format(selectedDate, 'yyyy-MM-dd')}` +
          `&time=${selectedHour}` +
          `&board_station_id=${firstStopId}` +
          `&exit_station_id=${lastStopId}`
        );
      })
      .then(res => res.json())
      .then(data => setSeats(hydrateSeatPayload(data)))
      .catch((err) => {
        console.error('Eroare:', err);
        setToastMessage(err.message);
        setToastType('error');
        setIsSaving(false);
        setTimeout(() => setToastMessage(''), 3000);
      });
  };


  // salvează cu verificare + efecte vizuale dacă lipsesc câmpuri
  const handleStartSave = () => {
    // validează fiecare pasager selectat folosind utilitarul existent
    const invalidSeatIds = selectedSeats
      .filter(seat => {
        const d = passengersData[seat.id];
        const v = isPassengerValid(d);
        return !v?.valid;
      })
      .map(seat => seat.id);

    if (invalidSeatIds.length > 0) {
      setShake(true);
      setTimeout(() => setShake(false), 600);
      // evidențiază câmpurile din fiecare formular al locului invalid
      invalidSeatIds.forEach(id => {
        const container = document.querySelector(`.passenger-form[data-seat="${id}"]`);
        if (!container) return;
        container.classList.add('animate-shake', 'border-red-500');
        setTimeout(() => container.classList.remove('border-red-500'), 800);
        const inputs = container.querySelectorAll('input, select, textarea');
        inputs.forEach(inp => {
          inp.classList.add('border-red-500');
          setTimeout(() => inp.classList.remove('border-red-500'), 800);
        });
      });
      setToastMessage('Completează toate câmpurile obligatorii înainte de salvare');
      setToastType('error');
      setTimeout(() => setToastMessage(''), 2000);
      return;
    }
    if (blacklistInfo?.blacklisted) {
      setShowBlacklistModal(true);
      return;
    }
    handleSaveReservation();
  };






  const handleSaveReservation = async () => {
    // 1) verificăm conflicte same-day, same-direction, altă oră
    const dateStr = format(selectedDate, 'yyyy-MM-dd');
    const firstSeatId = selectedSeats[0]?.id;
    const d = passengersData[firstSeatId] || {};
    const boardStationId = getStationIdByName(d.board_at);
    const exitStationId = getStationIdByName(d.exit_at);
    if (boardStationId === null || exitStationId === null) {
      setToastMessage('Stațiile selectate nu sunt valide pentru această rută.');
      setToastType('error');
      setTimeout(() => setToastMessage(''), 3000);
      return;
    }


    let conflict = false;
let infos = [];



// dacă nu avem person_id (telefon nou, persoană inexistentă), nu verificăm conflictul
if (!d.person_id) {
  console.log('Conflict skipped: no person_id');
} else {
  const qs = new URLSearchParams({
    person_id: String(d.person_id),
    date: dateStr,
    board_station_id: String(boardStationId),
    exit_station_id: String(exitStationId),
    time: selectedHour
  });
  const resp = await fetch(`/api/reservations/conflict?${qs.toString()}`);
const data = await resp.json();
conflict = data.conflict;
infos = data.infos;
if (conflict) {
  handleConflictInfoUpdate(infos);
  setShowConflictModal(true);
  return; // nu continuăm până nu confirmă user-ul
}

}

    if (conflict) {
      handleConflictInfoUpdate(infos);
      setShowConflictModal(true);
      return; // nu continuăm până nu confirmă user-ul
    }

    // 2) validări locale (pasageri, trip)
    const invalids = Object.values(passengersData)
      .map(p => isPassengerValid(p))
      .filter(v => !v.valid);
    if (invalids.length > 0) {
      const firstError = invalids[0].errors;
      setToastMessage(firstError.general || firstError.name || firstError.phone);
      setToastType('error');
      setTimeout(() => setToastMessage(''), 3000);
      return;
    }
    if (!selectedTrip) {
      setToastMessage('Tripul nu este încărcat. Încearcă din nou.');
      setToastType('error');
      return;
    }

    // 3) dacă ajungem aici, nu-s conflicte → trimitem rezervarea

    submitReservation();
  };


  // ═════ Când schimbi ruta, ștergem ora și harta ═════
  useEffect(() => {
    // Dacă nu e nicio rută selectată, nu e nimic de resetat
    if (!selectedRoute) return;

    // Ștergem ora (asta va opri efectul care încarcă seats)
    setSelectedHour(null);

    // Golim și harta
    setSeats([]);
    setVehicleInfo(null);
    setTripId(null);
  }, [selectedRoute]);





  useEffect(() => {
    if (!selectedRoute || !selectedHour || !selectedDate) return;

    setActiveTv('main');
    setSeats([]);
    setVehicleInfo(null);
    setTripId(null);
    setIsLoadingSeats(true); // <- pornim loaderul

    const loadSeats = async () => {
      try {
        const firstStopName = stops?.[0] || '';
        const lastStopName = stops?.slice(-1)[0] || '';
        const firstStopId = getStationIdByName(firstStopName);
        const lastStopId = getStationIdByName(lastStopName);

        if (firstStopId === null || lastStopId === null) {
          setIsLoadingSeats(false);
          return;
        }

        const tripRes = await fetch(
          `http://localhost:5000/api/trips/find?route_id=${selectedRoute.id}&date=${format(selectedDate, 'yyyy-MM-dd')}&time=${selectedHour}`
        );
        const tripData = await tripRes.json();
        const trip_id = tripData?.id;

        if (!trip_id) {
          setIsLoadingSeats(false); // nu există cursă, deci stop loader
          return;
        }
        setTripId(trip_id);
        setSelectedTrip(tripData);
        await fetchTripVehicles(tripData.id);

        const seatRes = await fetch(
          `http://localhost:5000/api/seats/${tripData.vehicle_id}?route_id=${selectedRoute.id}&date=${format(selectedDate, 'yyyy-MM-dd')}&time=${selectedHour}&board_station_id=${firstStopId}&exit_station_id=${lastStopId}`
        );
        const seatsData = await seatRes.json();
        setSeats(hydrateSeatPayload(seatsData));

        if (seatsData.length > 0) {
          setVehicleInfo({
            name: seatsData[0].vehicle_name,
            plate: seatsData[0].plate_number,
          });
        }
      } catch (err) {
        console.error('Eroare la încărcarea datelor:', err);
      } finally {
        setIsLoadingSeats(false); // termină loader oricum, și la eroare și la succes!
      }
    };

    loadSeats();
  }, [selectedRoute, selectedHour, selectedDate, hydrateSeatPayload, getStationIdByName]);
  ;





  const fetchTripVehicles = async (tripId) => {
    const res = await fetch(`/api/trips/${tripId}/vehicles`);
    const data = await res.json();

    // ataşăm plate_number din lista de availableVehicles
    const enriched = data.map(tv => {
      const veh = availableVehicles.find(v => v.id === tv.vehicle_id);
      return {
        ...tv,
        plate_number: veh?.plate_number || veh?.plate || ''
      };
    });

    setTripVehicles(enriched);
    return enriched;

  };



  // ─── Setăm tab-ul implicit pe "main" (mașina principală) când se încarcă cursa ───
  // SETEAZĂ activeTv PE CEL CORECT când tripVehicles se schimbă!
  useEffect(() => {
    if (!tripVehicles || tripVehicles.length === 0) return;

    // Caută tab-ul principal ("main"), altfel pune primul tab
    const mainTab = tripVehicles.find(tv => tv.is_primary);
    if (mainTab) {
      setActiveTv('main');
    } else {
      setActiveTv(tripVehicles[0].trip_vehicle_id);
    }
  }, [tripVehicles, selectedHour, selectedDate, selectedRoute]);









  useEffect(() => {
    // de fiecare dată când selecția orei sau tripId se schimbă,
    // retragem lista de vehicule pentru noua cursă+oră
    if (!tripId || !selectedHour) return;
    fetchTripVehicles(tripId);

    // 🔄 încarcă vehiculele disponibile (doar ale operatorului)
    fetch(`/api/vehicles/${tripId}/available`)
      .then(r => (r.ok ? r.json() : []))
      .then(setAvailableVehicles)
      .catch(() => setAvailableVehicles([]));
  }, [tripId, selectedHour]);







  useEffect(() => {
    // fără oră, nu cerem seat-map → evită 400 time=null
    if (!activeTv || !tripId || !selectedRoute || !selectedHour) return;

    // 1. Determinăm obiectul curent (principal sau dublură):
    const current =
      activeTv === 'main'
        ? { vehicle_id: selectedTrip.vehicle_id }
        : tripVehicles.find(tv => tv.trip_vehicle_id === activeTv);

    if (!current) return;

    (async () => {
      const firstStopName = stops[0];
      const lastStopName = stops.slice(-1)[0];
      const firstStopId = getStationIdByName(firstStopName);
      const lastStopId = getStationIdByName(lastStopName);
      if (firstStopId === null || lastStopId === null) {
        setSeats([]);
        return;
      }
      // 2. Încărcăm scaunele
      const res = await fetch(
        `/api/seats/${current.vehicle_id}` +
        `?route_id=${selectedRoute.id}` +
        `&date=${format(selectedDate, 'yyyy-MM-dd')}` +
        `&time=${encodeURIComponent(selectedHour)}` +
        `&board_station_id=${firstStopId}` +
        `&exit_station_id=${lastStopId}`
      );
      const data = await res.json();
      setSeats(hydrateSeatPayload(data));

      // 3. Folosim primul element din data pentru vehicleInfo
      if (data.length > 0) {
        setVehicleInfo({
          name: data[0].vehicle_name,
          plate: data[0].plate_number
        });
      }
    })();
  }, [activeTv, tripId, tripVehicles, selectedRoute, selectedDate, selectedHour, hydrateSeatPayload, getStationIdByName]);
  ;
  ;



  useEffect(() => {
    if (!selectedRoute || !selectedHour || !selectedDate || !seats.length) return;
    resetDefaultSeat();
  }, [selectedRoute, selectedHour, selectedDate, seats]);

  useEffect(() => {
    if (!selectedRoute || !selectedHour || !selectedDate || !seats.length) return;
    resetDefaultSeat();
  }, [seats]);


  const closePopups = () => {
    setPopupPassenger(null);
    setPopupSeat(null);
    setPopupPosition(null);
    setMultiPassengerOptions(null);
  };

  const handleDeletePassenger = async (passenger) => {
    try {
      const confirm = window.confirm(`Sigur vrei să ștergi pasagerul ${passenger.name}?`);
      if (!confirm) return;

      const res = await fetch(`http://localhost:5000/api/reservations/delete`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          phone: passenger.phone,
          board_station_id: passenger.board_station_id,
          exit_station_id: passenger.exit_station_id,
          trip_id: tripId,
          seat_id: popupSeat?.id,
        }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Eroare la ștergere');

      setToastMessage('Pasager șters cu succes ✅');
      setToastType('success');
      setTimeout(() => setToastMessage(''), 3000);
      closePopups();

      const firstStopId = getStationIdByName(stops[0]);
      const lastStopId = getStationIdByName(stops[stops.length - 1]);
      const refreshed = await fetch(
        `http://localhost:5000/api/seats/${selectedTrip.vehicle_id}?route_id=${selectedRoute.id}&date=${format(selectedDate, 'yyyy-MM-dd')}&time=${selectedHour}&board_station_id=${firstStopId}&exit_station_id=${lastStopId}`
      );
      const updated = await refreshed.json();
      setSeats(hydrateSeatPayload(updated));
    } catch (err) {
      console.error('Eroare la ștergere pasager:', err);
      setToastMessage('Eroare la ștergere');
      setToastType('error');
      setTimeout(() => setToastMessage(''), 3000);
    }
  };

  const handleSeatClick = (e, seat) => {
    if (!seat || !seat.passengers || seat.passengers.length === 0) return;
    const { clientX, clientY } = e;

    closePopups();

    if (seat.passengers.length === 1) {
      setPopupPassenger({
        ...seat.passengers[0],
        route_id: selectedRoute?.id    // ← AICI!
      });
      setPopupSeat(seat);
      setPopupPosition({ x: clientX, y: clientY });
    } else {
      setMultiPassengerOptions({ x: clientX, y: clientY, seat });
    }

  };


  ;

  return (

    <div className="min-h-screen bg-gray-100 flex justify-center items-start py-10 px-6 w-full">
      <Toast message={toastMessage} type={toastType} />

      <div className="inline-block space-y-6">
        <div className="flex flex-col md:inline-flex md:flex-row gap-6 items-start">
          <div className="bg-white rounded shadow p-4 w-fit">
            <label className="block font-semibold mb-2">Selectează data:</label>
            <CalendarWrapper selectedDate={selectedDate} setSelectedDate={setSelectedDate} />

          </div>

          <div className="bg-white rounded shadow p-4 space-y-4 w-fit">
            <div className="flex justify-between items-center flex-wrap gap-4">
              {/* Butoane rapide */}
              <div className="flex gap-2">
                {['Azi', 'Mâine', 'Poimâine'].map((label, idx) => {
                  const date = addDays(new Date(), idx);
                  const isActive =
                    format(selectedDate, 'yyyy-MM-dd') === format(date, 'yyyy-MM-dd');

                  return (
                    <button
                      key={label}
                      onClick={() => {
                        setSelectedDate(date);
                        setSelectedSeats([]);
                        setPassengersData({});
                        setSeats([]);
                      }}
                      className={`px-3 py-1 rounded text-sm font-medium transition ${isActive
                        ? 'bg-blue-600 text-white'
                        : 'bg-blue-100 text-black hover:bg-blue-200'
                        }`}
                    >
                      {label}
                    </button>
                  );
                })}
              </div>

              {/* Afișare dată + zi pronunțat */}
              <div className="text-base font-semibold text-gray-800">
                {format(selectedDate, 'EEEE, dd MMMM yyyy', { locale: ro })}
              </div>
            </div>

            <div>


              <RouteSelector
                routes={routesList}
                selectedRoute={selectedRoute}
                setSelectedRoute={setSelectedRoute}
              />

            </div>



            {selectedRoute && (
              <div>

                <div className="flex flex-wrap gap-3 mb-6">
                  <HourSelector
                    selectedRoute={selectedRoute}
                    selectedHour={selectedHour}
                    setSelectedHour={setSelectedHour}
                  />
                </div>

                {selectedHour && (
                  <div className="flex justify-between items-center mb-4">
                    <div className="flex gap-4">
                      <VehicleSelector
                        availableVehicles={availableVehicles}
                        vehicleInfo={vehicleInfo}
                        setVehicleInfo={setVehicleInfo}
                        showPopup={showVehiclePopup}
                        setShowPopup={setShowVehiclePopup}
                        setSelectedSeats={setSelectedSeats}
                        setSeats={setSeats}
                        setSelectedRoute={setSelectedRoute}
                        tripId={tripId}
                        setToastMessage={setToastMessage}
                        setToastType={setToastType}
                        stops={routeStations.map(s => s.name)}

                      />
                    </div>


                  </div>
                )}

                {selectedHour && (
                  <div className="mb-4 flex items-center border-b space-x-4">
                    {tabs.map((tv, idx) => (
                      <div
                        key={tv.trip_vehicle_id}
                        className="flex items-center -mb-px space-x-1"
                      >
                        {/* Tab propriu-zis */}
                        <button
                          onClick={() => setActiveTv(tv.is_primary ? 'main' : tv.trip_vehicle_id)}
                          className={`px-4 py-2 rounded-t-lg text-sm font-medium mr-1 transition-all duration-300
  ${(tabs.length === 1 || activeTv === (tv.is_primary ? 'main' : tv.trip_vehicle_id))
                              ? 'bg-white text-gray-900 border border-b-transparent shadow-md'
                              : 'bg-gray-100 text-gray-500 hover:bg-gray-200 border border-transparent'
                            }
`}
                        >
                          {tv.is_primary ? 'Principal' : `Dublură ${idx}`}
                        </button>

                        {/* Iconiță Modifică */}
                        <button
                          onClick={() => {
                            setActiveTv(tv.is_primary ? 'main' : tv.trip_vehicle_id);
                            setShowAddVeh(true);
                          }}
                          className="p-1 hover:bg-gray-200 rounded"
                          title="Modifică maşină"
                        >
                          ✏️
                        </button>

                        {/* Iconiță Șterge */}
                        {!tv.is_primary && (
                          <button
                            onClick={() => setConfirmTvToDelete(tv.trip_vehicle_id)}
                            className="p-1 hover:bg-gray-200 rounded"
                            title="Șterge maşină"
                          >
                            ❌
                          </button>
                        )}

                        <ConfirmModal
                          show={confirmTvToDelete === tv.trip_vehicle_id}
                          title="Confirmare ștergere"
                          message="Ești sigur că vrei să ștergi această mașină?"
                          onCancel={() => setConfirmTvToDelete(null)}
                          onConfirm={async () => {
                            const id = confirmTvToDelete;
                            setConfirmTvToDelete(null);

                            // 1) DELETE
                            const res = await fetch(
                              `/api/trips/${tripId}/vehicles/${id}`,
                              { method: 'DELETE' }
                            );
                            const json = await res.json();
                            if (!res.ok) {
                              setToastMessage(json.error);
                              setToastType('error');
                              setTimeout(() => setToastMessage(''), 3000);
                              return;
                            }

                            // 2) Toast de succes
                            setToastMessage('Mașina a fost ștearsă cu succes');
                            setToastType('success');
                            setTimeout(() => setToastMessage(''), 3000);

                            // 3) Refresh lista și seat-map
                            await fetchTripVehicles(tripId);
                            setActiveTv(prev => (prev === id ? 'main' : prev));
                          }}
                        />





                      </div>
                    ))}



                    {/* Butonul “Adaugă maşină” rămâne la fel */}
                    <button
                      onClick={() => {
                        setActiveTv(null);
                        setShowAddVeh(true);
                      }}
                      className="
    ml-4 
    flex-shrink-0 
    w-10 h-10 
    bg-green-500 hover:bg-green-600 
    text-white 
    rounded-full 
    flex items-center justify-center 
    shadow-md 
    transition-transform duration-150 
    hover:scale-110
  "
                      title="Adaugă mașină"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        className="w-6 h-6"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M12 4v16m8-8H4"
                        />
                      </svg>
                    </button>
                  </div>
                )}





              </div>
            )}
          </div>





        </div>

        {selectedHour && (
          isLoadingSeats ? (
            <div style={{ padding: 40, textAlign: "center", fontSize: 22 }}>
              Se încarcă harta locurilor...
            </div>
          ) : seats.length > 0 && (
            <div className="bg-white rounded shadow p-4 flex gap-6 items-start w-fit mx-auto">
              {/* Harta locurilor */}
              <div>
                <div className="font-semibold mb-3">Selectează locurile:</div>
                {vehicleInfo && (
                  <div className="text-sm text-gray-700 mb-2 font-semibold text-center">
                    Vehicul: {vehicleInfo.name} ({vehicleInfo.plate})
                  </div>
                )}
                {seats.length > 0 && (
                  <SeatMap
                    seats={seats}
                    stops={stops}
                    selectedSeats={selectedSeats}
                    setSelectedSeats={setSelectedSeats}
                    moveSourceSeat={moveSourceSeat}
                    setMoveSourceSeat={setMoveSourceSeat}
                    popupPassenger={popupPassenger}
                    setPopupPassenger={setPopupPassenger}
                    popupSeat={popupSeat}
                    setPopupSeat={setPopupSeat}
                    popupPosition={popupPosition}
                    setPopupPosition={setPopupPosition}
                    handleMovePassenger={handleMovePassenger}
                    handleSeatClick={handleSeatClick}
                    toggleSeat={toggleSeat}
                    isSeatFullyOccupiedViaSegments={isSeatFullyOccupiedViaSegments}
                    checkSegmentOverlap={checkSegmentOverlap}
                    selectedRoute={selectedRoute}
                    setToastMessage={setToastMessage}
                    setToastType={setToastType}

                    vehicleId={
                      tabs.find(tv => tv.trip_vehicle_id === activeTv)?.vehicle_id
                    }
                  />
                )}



              </div>

              {/* Formulare pasageri */}
              <div className="space-y-4 max-w-md w-[450px]">
                <div className="flex justify-between items-center">
                  <div className="font-semibold">Completează datele pasagerilor:</div>

                </div>

                {selectedSeats.map((seat, index) => (
                  <div
                    key={seat.id + "-" + index}
                    data-seat={seat.id}
                    className={`passenger-form border p-4 bg-gray-50 rounded space-y-2 ${shake ? 'animate-shake' : ''
                      }`}
                  >

                    <div className="flex gap-4">



                      <PassengerForm
                        seat={seat}
                        stops={stops}
                        passengersData={passengersData}
                        setPassengersData={setPassengersData}
                        selectedRoute={selectedRoute}
                        findAvailableSeatForSegment={findAvailableSeatForSegment}
                        setSelectedSeats={setSelectedSeats}
                        fetchPrice={fetchPrice}
                        toggleSeat={toggleSeat}
                        seats={seats}
                        selectedDate={format(selectedDate, 'yyyy-MM-dd')}
                        selectedHour={selectedHour}
                        onConflictInfo={handleConflictInfoUpdate}
                        onBlacklistInfo={setBlacklistInfo}
                        getStationIdByName={getStationIdByName}
                        getStationNameById={getStationNameById}

                      />


                    </div>



                    <div className="h-1 flex justify-end items-center">
                      <button
                        type="button"
                        className="text-blue-600 text-xl font-bold hover:text-blue-800"
                        onClick={() =>
                          setNotesVisibility((prev) => ({
                            ...prev,
                            [seat.id]: !prev[seat.id],
                          }))
                        }
                        title="Adaugă observații"
                      >
                        {notesVisibility[seat.id] ? '−' : '+'}
                      </button>
                    </div>

                    {notesVisibility[seat.id] && (
                      <textarea
                        className="w-full border p-2 rounded"
                        placeholder="Observații"
                        value={passengersData[seat.id]?.observations || ''}
                        onChange={(e) =>
                          setPassengersData((prev) => ({
                            ...prev,
                            [seat.id]: {
                              ...prev[seat.id],
                              observations: e.target.value,
                            },
                          }))
                        }
                      />


                    )}



                    <div className="flex items-center mb-2 space-x-4">
                      <label className="font-medium">Categorie:</label>
                      <select
                        className="ml-2 border rounded px-2 py-1 text-sm"
                        value={passengersData[seat.id]?.category_id ?? pricingCategories[0]?.id ?? ''}
                        onChange={e => {
                          const catId = e.target.value ? Number(e.target.value) : null;
                          setPassengersData(prev => ({
                            ...prev,
                            [seat.id]: {
                              ...prev[seat.id],
                              category_id: catId
                            }
                          }));
                          // forțăm re-fetch price
                          setPricePerSeat(prev => ({ ...prev, [seat.id]: null }));
                        }}
                      >
                        {pricingCategories.map(c => (
                          <option key={c.id} value={c.id}>
                            {c.name}
                          </option>
                        ))}
                      </select>
                    </div>










                    <div className="flex items-center mb-2">
                      <span className="font-medium">
                        Preț:
                        {(() => {
                          const price = pricePerSeat[seat.id];
                          if (typeof price !== 'number') return ' N/A';

                          const discId = passengersData[seat.id]?.discount_type_id;
                          const disc = routeDiscounts.find(d => d.id === discId);
                          if (!disc) {
                            return ` ${price.toFixed(2)} lei`;
                          }

                          const val = parseFloat(disc.discount_value);
                          let raw = 0;
                          if (disc.discount_type === 'percent') {
                            raw = price * (1 - val / 100);
                          } else {
                            raw = price - val;
                          }

                          // clamp la zero
                          const finalPrice = Math.max(raw, 0);

                          return (
                            <>
                              {' '}
                              <s>{price.toFixed(2)} lei</s>
                              <span className="ml-2 text-green-700 font-bold">
                                {finalPrice.toFixed(2)} lei
                              </span>
                              {raw < 0 && (
                                <span className="ml-2 text-red-600 font-semibold">
                                  Reducere prea mare, preț setat la 0
                                </span>
                              )}
                            </>
                          );
                        })()}
                      </span>

                      <select
                        className="ml-4 border rounded px-2 py-1 text-sm"
                        style={{ minWidth: 170 }}
                        value={passengersData[seat.id]?.discount_type_id || ''}
                        onChange={e =>
                          setPassengersData(prev => ({
                            ...prev,
                            [seat.id]: {
                              ...prev[seat.id],
                              discount_type_id: e.target.value ? Number(e.target.value) : null
                            }
                          }))
                        }
                      >
                        <option value="">Fără reducere</option>
                        {routeDiscounts.map(d => {
                          const v = parseFloat(d.discount_value);
                          const suffix = d.discount_type === 'percent' ? '%' : ' lei';
                          return (
                            <option key={d.id} value={d.id}>
                              {d.label} ({v}{suffix})
                            </option>
                          );
                        })}
                      </select>
                    </div>







                    <div className="mt-2">
                      <label className="text-sm font-medium">Modalitate de plată:</label>
                      <div className="flex gap-4 mt-1">
                        <label>
                          <input
                            type="radio"
                            name={`payment_${seat.id}`}
                            value="none"
                            checked={passengersData[seat.id]?.payment_method === 'none'}
                            onChange={() =>
                              setPassengersData((prev) => ({
                                ...prev,
                                [seat.id]: {
                                  ...prev[seat.id],
                                  payment_method: 'none',
                                },
                              }))
                            }
                          />
                          <span className="ml-1">Doar rezervare</span>
                        </label>

                        <label>
                          <input
                            type="radio"
                            name={`payment_${seat.id}`}
                            value="cash"
                            checked={passengersData[seat.id]?.payment_method === 'cash'}
                            onChange={() =>
                              setPassengersData((prev) => ({
                                ...prev,
                                [seat.id]: {
                                  ...prev[seat.id],
                                  payment_method: 'cash',
                                },
                              }))
                            }
                          />
                          <span className="ml-1">Cash</span>
                        </label>

                        <label>
                          <input
                            type="radio"
                            name={`payment_${seat.id}`}
                            value="card"
                            checked={passengersData[seat.id]?.payment_method === 'card'}
                            onChange={() =>
                              setPassengersData((prev) => ({
                                ...prev,
                                [seat.id]: {
                                  ...prev[seat.id],
                                  payment_method: 'card',
                                },
                              }))
                            }
                          />
                          <span className="ml-1">Card</span>
                        </label>
                      </div>

                      {passengersData[seat.id]?.payment_method === 'card' && (
                        <input
                          type="text"
                          placeholder="ID tranzacție POS"
                          className="mt-2 p-1 border rounded w-full text-sm"
                          value={passengersData[seat.id]?.transaction_id || ''}
                          onChange={(e) =>
                            setPassengersData((prev) => ({
                              ...prev,
                              [seat.id]: {
                                ...prev[seat.id],
                                transaction_id: e.target.value,
                              },
                            }))
                          }
                        />
                      )}
                    </div>














                    {passengersData[seat.id]?.reservation_id && (
                      <div className="flex justify-end pt-2">
                        <button
                          onClick={() => {
                            setPassengersData((prev) => {
                              const updated = { ...prev };
                              delete updated[seat.id];
                              return updated;
                            });

                            setSelectedSeats((prev) =>
                              prev.filter((s) => s.id !== seat.id)
                            );
                          }}
                          className="text-sm text-red-600 hover:underline"
                        >
                          Renunță la editare
                        </button>
                      </div>
                    )}


                  </div>
                ))}


                {/* Total de plată */}
                {selectedSeats.length > 0 && (
                  <div className="py-3 text-lg font-semibold text-green-700 text-right">
                    Total de plată: {getTotalToPay()} lei
                  </div>
                )}

                {selectedSeats.length > 0 && (
                  <div className="flex w-full pt-4" style={{
                    justifyContent: selectedSeats.length > 1 ? "space-between" : "flex-end"
                  }}>







                    {selectedSeats.length > 1 && (
                      <button
                        onClick={handleCopyPassengerData}
                        className="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700"
                      >
                        Copie datele
                      </button>
                    )}

                    <button
                      onClick={handleStartSave}
                      disabled={isSaving}
                      className={`px-6 py-2 rounded text-white transition ${isSaving ? 'bg-gray-300 cursor-not-allowed' : 'bg-green-600 hover:bg-green-700'
                        }`}
                    >
                      {isSaving ? 'Se salvează…' : 'Salvează rezervarea'}
                    </button>
                  </div>
                )}




              </div>





              <ConfirmModal

                show={showConflictModal}
                title="Rezervări conflictuale"
                message={`Mai există ${conflictCount} ${rezervareWord} (în aceeași zi):`}
                cancelText="Renunță"
                confirmText="Continuă"
                onCancel={() => setShowConflictModal(false)}
                onConfirm={() => {
                  setShowConflictModal(false);
                  submitReservation();
                }}
              >
                <ul className="space-y-2">
                  {(conflictInfo ?? []).map(c => (
                    <li key={c.id} className="flex justify-between items-center text-sm whitespace-nowrap">
                      <span className="whitespace-nowrap">
                        +         {c.route} • {c.time.slice(0, 5)} • {c.board_at}→{c.exit_at}
                      </span>
                      <button
                        onClick={async () => {
                          // confirmare nativă
                          if (!window.confirm('Ești sigur că vrei să ștergi această rezervare conflictuală?')) {
                            return;
                          }
                          try {
                            const res = await fetch(
                              `http://localhost:5000/api/reservations/${c.id}`,
                              { method: 'DELETE' }
                            );
                            const data = await res.json();
                            if (!res.ok) throw new Error(data.error || 'Eroare la ștergere');
                            // actualizează lista
                            setConflictInfo(prev => prev.filter(x => x.id !== c.id));
                            if (conflictInfo.length === 1) setShowConflictModal(false);
                            // feedback
                            setToastMessage('Rezervare conflictuală ștearsă');
                            setToastType('success');
                          } catch (err) {
                            setToastMessage(err.message);
                            setToastType('error');
                          } finally {
                            setTimeout(() => setToastMessage(''), 3000);
                          }
                        }}
                        className="px-2 py-1 bg-red-100 text-red-600 rounded hover:bg-red-200 ml-4"
                      >
                        Șterge
                      </button>
                    </li>
                  ))}
                </ul>
              </ConfirmModal>

              <ConfirmModal
                show={showBlacklistModal && blacklistInfo !== null}
                title="Avertisment: Blacklist"
                cancelText="Renunță"
                confirmText="Continuă"
                onCancel={() => setShowBlacklistModal(false)}
                onConfirm={() => {
                  setShowBlacklistModal(false);
                  handleSaveReservation();
                }}
              >
                <div className="text-sm space-y-2">
                  <p><strong>Telefon:</strong> {blacklistInfo?.phone || '-'}</p>
                  <p><strong>Motiv:</strong> {blacklistInfo?.reason || '-'}</p>
                  <p>
                    <strong>Adăugat la:</strong>{' '}
                    {blacklistInfo?.created_at
                      ? new Date(blacklistInfo.created_at).toLocaleDateString()
                      : '-'}
                  </p>
                  <p>Chiar vrei să continui?</p>
                </div>
              </ConfirmModal>










            </div>
          )
        )}

      </div>

      {multiPassengerOptions && (
        <MultiPassengerPopup
          x={multiPassengerOptions.x}
          y={multiPassengerOptions.y}
          seat={multiPassengerOptions.seat}
          selectedRoute={selectedRoute}
          onSelect={(passenger) => {
            setPopupPassenger({
              ...selectedPassenger,
              route_id: selectedRoute?.id,  // <-- adaugi route_id direct aici!
            });
            setPopupSeat(multiPassengerOptions.seat);
            setPopupPosition({ x: multiPassengerOptions.x, y: multiPassengerOptions.y });
            setMultiPassengerOptions(null);
          }}
          onClose={() => setMultiPassengerOptions(null)}
        />
      )}

      {popupPassenger && popupPosition && (
        <PassengerPopup
          // poziționare popup
          x={popupPosition.x}
          y={popupPosition.y}

          // datele pasagerului și locul
          passenger={popupPassenger}
          seat={popupSeat}

          // data și ora curentă pentru filtrare
          selectedDate={selectedDate}
          selectedHour={selectedHour}
          originalRouteId={selectedRoute?.id}

          // contextul rezervării

          tripId={tripId}

          // toast-uri
          setToastMessage={setToastMessage}
          setToastType={setToastType}
          stops={routeStations.map(s => s.name)}

          // acțiuni standard
          onDelete={() => handleDeletePassenger(popupPassenger)}
          onMove={() => {
            setMoveSourceSeat(popupSeat);
            closePopups();
            setToastMessage('Selectează un loc pentru mutare');
            setToastType('info');
          }}

          onEdit={() => {
            console.log('PassengerPopup onEdit – popupSeat:', popupSeat.label);
            const seatId = popupSeat.id;
            setSelectedSeats([popupSeat]);
            // rescrie întreg obiectul: rămâne DOAR pasagerul editat
            setPassengersData({
              [seatId]: {
                name: popupPassenger.name,
                phone: popupPassenger.phone,
                board_at: popupPassenger.board_at,
                exit_at: popupPassenger.exit_at,
                observations: popupPassenger.observations || '',
                reservation_id: popupPassenger.reservation_id || null,
              },
            });
            closePopups();
          }}

          // mutare pe altă cursă
          onMoveToOtherTrip={() => {
            closePopups();
            setMoveToOtherTripData({
              passenger: popupPassenger,
              reservation_id: popupPassenger.reservation_id,
              fromSeat: popupSeat,
              boardAt: popupPassenger.board_at,
              exitAt: popupPassenger.exit_at,
              originalTime: selectedHour,
              originalRouteId: selectedRoute?.id,
              originalDate: selectedDate,
            });
            setShowMoveToOtherTrip(true);
          }}

          // închidere
          onClose={closePopups}
        />
      )}



      {toastMessage && (
        <Toast message={toastMessage} type={toastType} />
      )}

      {multiPassengerOptions && (
        <MultiPassengerPopup
          x={multiPassengerOptions.x}
          y={multiPassengerOptions.y}
          seat={multiPassengerOptions.seat}
          onSelect={(passenger) => {
            setPopupPassenger({
              ...passenger,
              route_id: selectedRoute?.id  // ASTA ERA CHEIA!
            });
            setPopupSeat(multiPassengerOptions.seat);
            setPopupPosition({
              x: multiPassengerOptions.x,
              y: multiPassengerOptions.y
            });
            setMultiPassengerOptions(null);
          }}
          onClose={() => setMultiPassengerOptions(null)}
        />
      )}

      {showMoveToOtherTrip && (
        <MoveToOtherTripPanel
          moveToOtherTripData={moveToOtherTripData}
          stops={stops}

          // 📌 callback care reîncarcă seats pentru CURSA ORIGINALĂ
          onClose={async () => {
            setShowMoveToOtherTrip(false);
            setMoveToOtherTripData(null);
            if (!selectedHour) return;
            const tv = tripVehicles.find(tv => tv.trip_vehicle_id === activeTv);
            const vehicleId = tv ? tv.vehicle_id : selectedTrip.vehicle_id;
            const firstStopId = getStationIdByName(stops[0]);
            const lastStopId = getStationIdByName(stops.slice(-1)[0]);
            try {
              const res = await fetch(
                `/api/seats/${vehicleId}` +
                `?route_id=${selectedRoute.id}` +
                `&date=${format(selectedDate, 'yyyy-MM-dd')}` +
                `&time=${encodeURIComponent(selectedHour)}` +
                `&board_station_id=${firstStopId}` +
                `&exit_station_id=${lastStopId}`
              );
              const data = await res.json();
              setSeats(hydrateSeatPayload(data));
            } catch (err) {
              console.error('Eroare la reîncărcare seat-map:', err);
            }
          }}

          // 📌 callback care reîncarcă seats pentru CURSA NOUĂ
          onMoveSuccess={async ({ tripId, vehicleId, routeId, date, hour }) => {
            try {
              const stationsRes = await fetch(`/api/routes/${routeId}/stations`);
              const stations = await stationsRes.json();
              const sortedStations = Array.isArray(stations)
                ? [...stations].sort((a, b) => (a.sequence ?? 0) - (b.sequence ?? 0))
                : [];
              const firstStationId = sortedStations[0]?.station_id ?? null;
              const lastStationId = sortedStations[sortedStations.length - 1]?.station_id ?? null;
              if (firstStationId === null || lastStationId === null) {
                console.error('Stațiile rutei mutate lipsesc.');
                return;
              }

              const seatsRes = await fetch(
                `/api/seats/${vehicleId}` +
                `?route_id=${routeId}` +
                `&date=${format(date, 'yyyy-MM-dd')}` +
                `&time=${hour}` +
                `&board_station_id=${firstStationId}` +
                `&exit_station_id=${lastStationId}`
              );
              const data = await seatsRes.json();
              const route = routesList.find(r => r.id === routeId) || null;
              setSelectedRoute(route);
              setSelectedDate(date);
              setSelectedHour(hour);
              setSeats(hydrateSeatPayload(data));
            } catch (err) {
              console.error('Eroare la fetch cursă nouă:', err);
            }
          }}
        />
      )}


      <AddVehicleModal
        tripId={tripId}
        show={showAddVeh}
        onClose={() => setShowAddVeh(false)}

        existingVehicleIds={
          // excludem absolut toate vehiculele deja alocate (principal + dubluri)
          tabs.map(t => t.vehicle_id)
        }
        editTvId={activeTv}

        onAdded={(newTv) => {
          // callback pentru Adaugă maşină
          setTripVehicles(prev => [...prev, newTv]);
          setActiveTv(newTv.trip_vehicle_id);
          setShowAddVeh(false);
        }}

        onUpdated={async (newVehicleIdOrTv) => {
          // — dacă e maşina principală —
          if (activeTv === 'main') {
            setSelectedTrip(prev => ({
              ...prev,
              vehicle_id: newVehicleIdOrTv
            }));
            await fetchTripVehicles(tripId);
            // ─── RELOAD seats ─────────────────────────
            const first = getStationIdByName(stops[0]);
            const last = getStationIdByName(stops[stops.length - 1]);
            const seatRes = await fetch(
              `/api/seats/${newVehicleIdOrTv}?route_id=${selectedRoute.id}` +
              `&date=${format(selectedDate, 'yyyy-MM-dd')}` +
              `&time=${encodeURIComponent(selectedHour)}` +
              `&board_station_id=${first}` +
              `&exit_station_id=${last}`
            );
            setSeats(hydrateSeatPayload(await seatRes.json()));
            // forţăm reîncărcarea SeatMap prin schimbarea vehicle_id
            setActiveTv('main');
            setShowAddVeh(false);
            return;
          }

          // — dacă e o dublură —
          const updatedTv = newVehicleIdOrTv; // conține trip_vehicle_id & vehicle_id

          // 1) Reîncărcăm lista de dubluri
          await fetchTripVehicles(tripId);

          // 2) Comutăm pe tab-ul editat
          setActiveTv(updatedTv.trip_vehicle_id);

          // 3) Încărcăm **manual** harta scaunelor pentru noul vehicul
          const firstStop = getStationIdByName(stops[0]);
          const lastStop = getStationIdByName(stops[stops.length - 1]);
          const resSeats = await fetch(
            `/api/seats/${updatedTv.vehicle_id}` +
            `?route_id=${selectedRoute.id}` +
            `&date=${format(selectedDate, 'yyyy-MM-dd')}` +
            `&time=${selectedHour}` +
            `&board_station_id=${firstStop}` +
            `&exit_station_id=${lastStop}`
          );
          const seatsData = await resSeats.json();
          setSeats(hydrateSeatPayload(seatsData));

          // 4) Închidem modal-ul
          setShowAddVeh(false);
        }}
      />









    </div>
  );
}