// src/components/reservationLogic.js

/**
 * Selectează automat cel mai bun loc disponibil pentru segmentul dorit.
 */
export function getBestAvailableSeat(seats, board_at, exit_at, stops, excludeIds = []) {
  // Normalizare denumiri stații
  const normalize = (s) => s?.trim().toLowerCase();
  const boardIndex = stops.findIndex((s) => normalize(s) === normalize(board_at));
  const exitIndex = stops.findIndex((s) => normalize(s) === normalize(exit_at));

  if (boardIndex === -1 || exitIndex === -1 || boardIndex >= exitIndex) return null;

  // Ordonăm locurile după label (număr)
  const sortedSeats = [...seats].sort((a, b) => parseInt(a.label) - parseInt(b.label));

  // Căutăm locuri parțial ocupate dar compatibile
  const partialMatches = [];
  const fullMatches = [];

  for (const seat of sortedSeats) {
    if (excludeIds.includes(seat.id)) continue;
    if (seat.label.toLowerCase().includes('șofer')) continue;
    if (seat.status === 'full') continue;

    const passengers = Array.isArray(seat.passengers) ? seat.passengers : [];

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
}
