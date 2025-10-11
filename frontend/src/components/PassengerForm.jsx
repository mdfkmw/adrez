import React, { useState, useEffect } from 'react';
import Select from 'react-select';
import { isPassengerValid } from './utils/validation';
import { getBestAvailableSeat } from './reservationLogic';







const PassengerForm = ({
    seat,
    selectedRoute,
    passengersData,
    setPassengersData,
    selectedSeats,
    setSelectedSeats,
    fetchPrice,
    findAvailableSeatForSegment,
    setToastMessage,
    setToastType,
    toggleSeat,
    seats,
    selectedDate,
    selectedHour,

    onConflictInfo,
    onBlacklistInfo,
    stops = [],
    getStationIdByName,
    getStationNameById,
}) => {








    const passenger = passengersData[seat.id] || {};
    const { errors } = isPassengerValid(passenger);
    // ─── blacklist warning state ───
    const [blacklistInfo, setBlacklistInfo] = useState(null);
    const [showBlacklistDetails, setShowBlacklistDetails] = useState(false);
    const [personHistory, setPersonHistory] = useState(null);
    const [autoFilled, setAutoFilled] = useState(false);


    // starea pentru conflict
    const [conflictInfo, setConflictInfo] = useState([]);
    const [showConflictDetails, setShowConflictDetails] = useState(false);
    const [hasConflict, setHasConflict] = useState(false);
    useEffect(() => {

        const date = selectedDate;
        const time = selectedHour;
        const board = passenger.board_at;
        const exit = passenger.exit_at;

        if (!date || !time || !board || !exit) {
            setHasConflict(false);
            setConflictInfo(null);
            return;
        }

        const boardId = getStationIdByName ? getStationIdByName(board) : null;
        const exitId = getStationIdByName ? getStationIdByName(exit) : null;
        if (boardId === null || exitId === null) {
            setHasConflict(false);
            setConflictInfo([]);
            onConflictInfo([]);
            return;
        }
        if (!passenger.person_id) return; // așteaptă până avem person_id din blacklist/check
        const params = new URLSearchParams({
            date,
            board_station_id: boardId,
            exit_station_id: exitId,
            time,
            person_id: String(passenger.person_id)
        });


        fetch(`/api/reservations/conflict?${params.toString()}`)
            .then(r => r.json())
            .then(data => {
                if (data.conflict) {
                    setHasConflict(true);
                    const enriched = (data.infos || []).map(info => ({
                        ...info,
                        board_at: getStationNameById ? getStationNameById(info.board_station_id) : '',
                        exit_at: getStationNameById ? getStationNameById(info.exit_station_id) : ''
                    }));
                    setConflictInfo(enriched);
                    onConflictInfo(data.infos);
                } else {
                    setHasConflict(false);
                    setConflictInfo([]);      // golim array-ul
                    onConflictInfo([]);       // anunţăm parent-ul
                }
            })
            .catch(() => {
                setHasConflict(false);
                setConflictInfo([]);
                onConflictInfo([]);
            });
    }, [

        passenger.person_id,
        passenger.board_at,
        passenger.exit_at,
        selectedDate,
        selectedHour,
        getStationIdByName,
        getStationNameById
    ]);
    ;
    ;




    useEffect(() => {
        const raw = passenger.phone || '';
        const digits = raw.replace(/\D/g, '');

        setPersonHistory(null);
        setAutoFilled(false);

        if (!digits) {
            const prevData = passengersData[seat.id] || {};
            const isEdit = !!prevData.reservation_id;
            const hasName = (prevData.name || '').trim().length > 0;
            if (!isEdit && !hasName) {
                setPassengersData(prev => ({
                    ...prev,
                    [seat.id]: { ...prev[seat.id], name: '' }
                }));
            }
            return;
        }

        if (digits.length < 10) return;



        // Altfel, facem fetch pentru istoric și eventual autofill
        fetch(`/api/people/history?phone=${encodeURIComponent(digits)}`)
            .then(res => res.json())
            .then(data => {
                if (data.exists) {
                    const historyWithNames = Array.isArray(data.history)
                        ? data.history.map(item => ({
                            ...item,
                            board_at: getStationNameById ? getStationNameById(item.board_station_id) : '',
                            exit_at: getStationNameById ? getStationNameById(item.exit_station_id) : ''
                        }))
                        : [];
                    setPersonHistory({ ...data, history: historyWithNames });
                    if (!autoFilled && data.name) {
                        // auto-fill doar dacă nu există deja un name tastat
                        if (!passenger.name) {
                            setPassengersData(prev => ({
                                ...prev,
                                [seat.id]: {
                                    ...prev[seat.id],
                                    name: data.name
                                }
                            }));
                        }
                        setAutoFilled(true);
                    }
                } else {
                    setPersonHistory(null);
                    setAutoFilled(false);
                }
            })
            .catch(() => {
                setPersonHistory(null);
                setAutoFilled(false);
            });
    }, [passenger.phone, getStationNameById]);
    






    useEffect(() => {
        const rawPhone = passenger.phone || '';
        const digits = rawPhone.replace(/\D/g, '');

        // < 10 cifre → curățăm + nu facem request
        if (digits.length < 10) {
            setBlacklistInfo({
                phone: rawPhone,
                blacklisted: false,
                reason: null,
                no_shows: [],
                created_at: null
            });
            setPassengersData(prev => ({
                ...prev,
                [seat.id]: { ...prev[seat.id], person_id: null }
            }));
            return;
        }

        fetch(`/api/blacklist/check?phone=${encodeURIComponent(digits)}`)
            .then(res => res.json())
            .then(data => {
                // memorează person_id în formular (dacă vine)
                if (data.person_id) {
                    setPassengersData(prev => ({
                        ...prev,
                        [seat.id]: { ...prev[seat.id], person_id: data.person_id }
                    }));
                }

                // compune info pentru UI (numele stațiilor din ID)
                const noShows = Array.isArray(data.no_shows)
                    ? data.no_shows.map(item => ({
                        ...item,
                        board_at: getStationNameById ? getStationNameById(item.board_station_id) : '',
                        exit_at: getStationNameById ? getStationNameById(item.exit_station_id) : ''
                    }))
                    : [];

                const history = Array.isArray(data.blacklist_history) ? data.blacklist_history : [];
                const lastEntry = history[history.length - 1] || {};

                const enriched = {
                    phone: rawPhone,
                    blacklisted: data.blacklisted,
                    reason: data.reason,
                    no_shows: noShows,
                    created_at: lastEntry.created_at || null
                };

                setBlacklistInfo(enriched);
                onBlacklistInfo?.(enriched);
            })
            .catch(() => {
                setBlacklistInfo(null);
                onBlacklistInfo?.(null);
            });
    }, [passenger.phone, getStationNameById]);







    return (
        <div className="relative border p-2 rounded bg-white shadow space-y-2">
            <button
                onClick={() => toggleSeat(seat)}
                className="absolute top-2 right-2 text-gray-400 hover:text-red-500 font-bold text-lg"
                title="Deselectează locul"
            >
                ×
            </button>



            <div className="font-medium flex items-center gap-2">
                Loc:
                <Select
                    className="min-w-[100px] w-auto"
                    value={{ value: seat.id, label: seat.label }}
                    options={(() => {
                        const allStops = Array.isArray(stops) ? stops : [];
                        const board_at = passengersData[seat.id]?.board_at;
                        const exit_at = passengersData[seat.id]?.exit_at;

                        const boardIndex = allStops.findIndex(s => s === board_at);
                        const exitIndex = allStops.findIndex(s => s === exit_at);

                        const candidates = seats
                            .filter(s => {
                                if (s.label.toLowerCase().includes('șofer') || s.id === seat.id) return false;
                                if (s.status === 'full') return false;

                                const conflicts = s.passengers?.some(p => {
                                    const pBoard = allStops.findIndex(x => x === p.board_at);
                                    const pExit = allStops.findIndex(x => x === p.exit_at);
                                    return !(exitIndex <= pBoard || boardIndex >= pExit);
                                });

                                return !conflicts;
                            })
                            .sort((a, b) => parseInt(a.label) - parseInt(b.label));

                        return candidates.map(s => ({
                            value: s.id,
                            label: s.label,
                        }));
                    })()}
                    onChange={(selectedOption) => {
                        const newSeatId = selectedOption.value;
                        const oldSeatId = seat.id;
                        if (newSeatId === oldSeatId) return;

                        const newSeat = seats.find(s => s.id === newSeatId);
                        const data = passengersData[oldSeatId];

                        setSelectedSeats((prev) =>
                            prev.map((s) => (s.id === oldSeatId ? newSeat : s))
                        );

                        setPassengersData((prev) => {
                            const updated = { ...prev };
                            delete updated[oldSeatId];
                            updated[newSeatId] = { ...data };
                            return updated;
                        });
                    }}
                />
            </div>



            {/* 🔤 Nume și 📞 Telefon */}
            <div className="flex gap-4">
                {/* ─── Câmpul Nume pasager + Istoric ─── */}
                <div className="w-full relative">
                    <input
                        type="text"
                        className={`w-full p-2 border rounded ${errors.name ? 'border-red-500' : 'border-gray-300'}`}
                        placeholder="Nume pasager"
                        value={passenger.name || ''}
                        onChange={e => {
                            // dacă modifici manual numele, resetează flag-ul de auto-fill
                            setAutoFilled(false);
                            setPassengersData(prev => ({
                                ...prev,
                                [seat.id]: { ...prev[seat.id], name: e.target.value }
                            }));
                        }}
                    />
                    {/* Refresh icon: apare doar când avem sugestie și n-am aplicat-o încă */}
                    {autoFilled && personHistory?.name && passenger.name !== personHistory.name && (
                        <button
                            type="button"
                            onClick={() => {
                                // aplică numele sugerat
                                setPassengersData(prev => ({
                                    ...prev,
                                    [seat.id]: { ...prev[seat.id], name: personHistory.name }
                                }));
                                // ascunde iconița după aplicare
                                setAutoFilled(false);
                            }}
                            className="absolute right-2 top-2 text-gray-500 hover:text-gray-700"
                            title="Preia numele din baza de date"
                        >
                            🔄
                        </button>
                    )}
                    {errors.name && <div className="text-red-600 text-xs mt-1">{errors.name}</div>}
                </div>



                {/* ─── Câmpul Telefon + Istoric/Blacklist/No-shows ─── */}
                <div className="w-full relative">
                    <input
                        inputMode="tel"
                        pattern="^\+?\d*$"
                        type="text"
                        className={`w-full p-2 border rounded ${errors.phone ? 'border-red-500' : 'border-gray-300'}`}
                        placeholder="Telefon"
                        value={passenger.phone || ''}
                        onChange={(e) =>
                            setPassengersData(prev => ({
                                ...prev,
                                [seat.id]: { ...prev[seat.id], phone: e.target.value }
                            }))
                        }
                    />
                    {errors.phone && <div className="text-red-600 text-xs mt-1">{errors.phone}</div>}


                    {/* container pentru toate iconițele, ca să le poziționăm pe orizontală */}
                    <div className="absolute top-2 right-3 flex space-x-1">




                        {/* ℹ️ ISTORIC (doar dacă există history şi nu are no-shows şi nu e blacklist) */}
                        {personHistory?.exists && !blacklistInfo?.blacklisted && !(blacklistInfo?.no_shows?.length > 0) && (
                            <button
                                type="button"
                                onClick={() => {
                                    setShowBlacklistDetails(v => !v)
                                    setShowConflictDetails(false);
                                }}
                                className="text-blue-600 text-lg hover:opacity-75"
                                title="Vezi ultimele 5 rezervări"
                            >
                                ℹ️
                            </button>
                        )}

                        {/* ❗ NO-SHOWS (doar dacă are ne-prezentări, dar nu e blacklist) */}
                        {!blacklistInfo?.blacklisted && blacklistInfo?.no_shows?.length > 0 && (
                            <button
                                type="button"
                                onClick={() => setShowBlacklistDetails(v => !v)}
                                className="text-orange-600 text-lg hover:opacity-75"
                                title="Are neprezentări"
                            >
                                ❗
                            </button>
                        )}

                        {/* 🛑 BLACKLIST (prioritate) */}
                        {blacklistInfo?.blacklisted && (
                            <button
                                type="button"
                                onClick={() => {
                                    setShowBlacklistDetails(v => !v);
                                    setShowConflictDetails(false);
                                }}
                                className="text-red-600 text-lg hover:opacity-75"
                                title="Persoană în blacklist"
                            >
                                🛑
                            </button>
                        )}

                        {/* ⚠️ Triunghi galben pentru conflict */}
                        {hasConflict && (
                            <button
                                onClick={() => {
                                    setShowConflictDetails(v => !v);
                                    setShowBlacklistDetails(false);     // închidem istoric/blacklist
                                }}
                                className="inline-block text-yellow-500 text-lg hover:opacity-75 animate-pulse"
                                title="Există rezervare în aceeași zi pe același sens"
                            >
                                ⚠️
                            </button>
                        )}
                    </div>

                    {/* Popup comun pentru cele 3 situații */}
                    {hasConflict && showConflictDetails && conflictInfo.length > 0 && (
                        <>
                            {/* backdrop apăsat pentru click-outside */}
                            <div
                                className="fixed inset-0 z-40"
                                onClick={() => setShowConflictDetails(false)}
                            />
                            {/* fereastra efectivă de deasupra */}
                            <div className="absolute right-0 bottom-full mb-1 min-w-max 
                    bg-white p-3 border border-gray-200 rounded-lg 
                    shadow-lg z-50 text-sm whitespace-normal">
                                <div className="font-semibold mb-1">Rezervări conflictuale:</div>
                                <ul className="space-y-1">
                                    {conflictInfo.map((c, idx) => (
                                        <li key={idx} className="text-sm whitespace-nowrap">
                                            {c.route} • {c.time.slice(0, 5)} • Loc: {c.seatLabel} • {c.board_at}→{c.exit_at}
                                        </li>
                                    ))}
                                </ul>
                            </div>
                        </>
                    )}
                    {showBlacklistDetails && (
                        <>
                            {/* backdrop pentru închiderea la click în afara pop-up-ului */}
                            <div
                                className="fixed inset-0 z-40"
                                onClick={() => setShowBlacklistDetails(false)}
                            />
                            {/* fereastra vizibilă deasupra */}
                            <div className="absolute right-0 bottom-full mb-1 min-w-max 
                    bg-white p-3 border border-gray-200 rounded-lg 
                    shadow-lg z-50 text-sm whitespace-normal">
                                {blacklistInfo?.blacklisted ? (
                                    <>
                                        <div className="font-semibold mb-1 text-gray-800">Este în Blacklist</div>
                                        <div className="font-semibold mb-1 text-gray-700">Ultimele neprezentări:</div>
                                        <ul className="space-y-1 whitespace-nowrap">
                                            {blacklistInfo.no_shows.map((sh, idx) => (
                                                <li key={idx} className="text-sm">
                                                    • {sh.date} {sh.hour} – {sh.route_name} ({sh.board_at}→{sh.exit_at})
                                                </li>
                                            ))}
                                        </ul>
                                    </>
                                ) : blacklistInfo?.no_shows?.length > 0 ? (
                                    <>
                                        <div className="font-semibold mb-1">Neprezentări:</div>
                                        <ul className="space-y-1 whitespace-nowrap">
                                            {blacklistInfo.no_shows.map((sh, idx) => (
                                                <li key={idx} className="text-sm">
                                                    • {sh.date} {sh.hour} – {sh.route_name} ({sh.board_at}→{sh.exit_at})
                                                </li>
                                            ))}
                                        </ul>
                                    </>
                                ) : (
                                    <>
                                        <div className="font-semibold mb-1">Istoric rezervări</div>
                                        <ul className="space-y-1 whitespace-nowrap">
                                            {personHistory?.history?.map((sh, idx) => (
                                                <li key={idx} className="text-sm whitespace-nowrap">
                                                    • {sh.route_name} • {sh.time.slice(0, 5)} • Loc: {sh.seat_label} • {sh.board_at}→{sh.exit_at}
                                                </li>
                                            ))}
                                        </ul>
                                    </>
                                )}
                            </div>
                        </>
                    )}






                </div>


            </div>
            {/* 🚏 Urcă din / Coboară la */}
            <div className="flex gap-4">
                <Select
                    className="w-full"
                    options={(() => {
                        const allStops = stops || [];
                        const exitIndex = allStops.findIndex(
                            (s) => s === passengersData[seat.id]?.exit_at
                        );

                        const validStops =
                            exitIndex > 0 ? allStops.slice(0, exitIndex) : allStops;

                        return validStops.map((stop) => ({
                            value: stop,
                            label: stop,
                        }));
                    })()}
                    placeholder="Urcă din"
                    value={
                        passengersData[seat.id]?.board_at
                            ? {
                                value: passengersData[seat.id].board_at,
                                label: passengersData[seat.id].board_at,
                            }
                            : null
                    }
                    onChange={(selectedOption) => {
                        const newBoard = selectedOption.value;
                        setPassengersData(prev => {
                            const prevData = prev[seat.id] || {};
                            const { exit_at, reservation_id } = prevData;
                            const isEdit = !!reservation_id;

                            if (!isEdit) {
                                // 1) Lista de seat-IDs deja alocate în prev
                                const otherSelectedIds = Object.keys(prev)
                                    .map(k => Number(k))
                                    .filter(id => id !== seat.id);
                                // 2) Filtrăm lista de seats, excluzându-le
                                const filteredSeats = seats.filter(s => !otherSelectedIds.includes(s.id));
                                // 3) Alegem cel mai bun loc disponibil
                                const newSeat = getBestAvailableSeat(
                                    filteredSeats,
                                    newBoard,
                                    exit_at,
                                    stops,
                                    otherSelectedIds
                                );
                                if (!newSeat) {
                                    setToastMessage('Nu există loc disponibil pentru segmentul selectat.');
                                    setToastType('error');
                                    setTimeout(() => setToastMessage(''), 3000);
                                    return prev;
                                }
                                setSelectedSeats(list => list.map(s => s.id === seat.id ? newSeat : s));
                                fetchPrice(newSeat.id, newBoard, exit_at);
                                const updated = { ...prev };
                                delete updated[seat.id];
                                updated[newSeat.id] = { ...prevData, board_at: newBoard };
                                return updated;
                            }

                            fetchPrice(seat.id, newBoard, exit_at);
                            return {
                                ...prev,
                                [seat.id]: { ...prevData, board_at: newBoard },
                            };
                        });;
                    }}
                />

                <Select
                    className="w-full"
                    options={(() => {
                        const allStops = stops || [];
                        const boardIndex = allStops.findIndex(
                            (s) => s === passengersData[seat.id]?.board_at
                        );

                        const validStops =
                            boardIndex >= 0 ? allStops.slice(boardIndex + 1) : allStops;

                        return validStops.map((stop) => ({
                            value: stop,
                            label: stop,
                        }));
                    })()}
                    placeholder="Coboară la"
                    value={
                        passengersData[seat.id]?.exit_at
                            ? {
                                value: passengersData[seat.id].exit_at,
                                label: passengersData[seat.id].exit_at,
                            }
                            : null
                    }
                    onChange={(selectedOption) => {
                        const newExit = selectedOption.value;
                        setPassengersData(prev => {
                            const prevData = prev[seat.id] || {};
                            let { board_at, reservation_id } = prevData;
                            const isEdit = !!reservation_id;
                            const boardIndex = stops.findIndex(s => s === board_at);
                            const exitIndex = stops.findIndex(s => s === newExit);

                            if (boardIndex >= exitIndex) {
                                board_at = stops[0];
                            }

                            if (!isEdit) {
                                // 1) Lista de seat-IDs deja alocate în prev
                                const otherSelectedIds = Object.keys(prev)
                                    .map(k => Number(k))
                                    .filter(id => id !== seat.id);
                                // 2) Filtrăm lista de seats disponibile
                                const filteredSeats = seats.filter(s => !otherSelectedIds.includes(s.id));
                                // 3) Alegem cel mai bun loc disponibil
                                const newSeat = getBestAvailableSeat(
                                    filteredSeats,
                                    board_at,
                                    newExit,
                                    stops,
                                    otherSelectedIds
                                );
                                if (!newSeat) {
                                    setToastMessage('Nu există loc disponibil pentru segmentul selectat.');
                                    setToastType('error');
                                    setTimeout(() => setToastMessage(''), 3000);
                                    return prev;
                                }
                                setSelectedSeats(list => list.map(s => s.id === seat.id ? newSeat : s));
                                fetchPrice(newSeat.id, board_at, newExit);
                                const updated = { ...prev };
                                delete updated[seat.id];
                                updated[newSeat.id] = { ...prevData, board_at, exit_at: newExit };
                                return updated;
                            }

                            fetchPrice(seat.id, board_at, newExit);
                            return {
                                ...prev,
                                [seat.id]: { ...prevData, board_at, exit_at: newExit },
                            };
                        });;
                    }}
                />
            </div>















        </div>
    );
};

export default PassengerForm;
