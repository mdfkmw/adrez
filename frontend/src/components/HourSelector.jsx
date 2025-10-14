import React from 'react';

export default function HourSelector({ selectedRoute, selectedHour, setSelectedHour }) {
  if (!selectedRoute?.schedules?.length) {
    return <div className="text-gray-500">Nicio oră disponibilă pentru această rută.</div>;
  }

  return (
    <div className="mt-4">
      <div className="flex flex-wrap gap-2">
        {selectedRoute.schedules.map((sch, idx) => {
          const { departure, themeColor, disabledRun, disabledOnline, tripDisabled } = sch;
          const isActive   = selectedHour === departure;
          // offline disabled dacă trips.disabled==true sau disable_run==true
          // online disabled doar dacă disable_online==true
          const isDisabled = !!(Number(tripDisabled) || Number(disabledRun) || Number(disabledOnline));
          return (
            <button
              key={`${departure}-${idx}`}
              onClick={() => !isDisabled && setSelectedHour(departure)}
              disabled={isDisabled}
              aria-pressed={isActive}
              className={`
                px-2 py-0 rounded-lg border-1 focus:outline-none
                ${isActive
                  ? 'ring-2 ring-offset-2 ring-opacity-50'
                  : 'hover:ring-1 hover:ring-offset-1'}
                ${isDisabled
                  ? 'line-through text-gray-400 cursor-not-allowed'
                  : ''}
              `}
              style={{
                backgroundColor: themeColor + '20',
                borderColor: themeColor
              }}
            >
              {departure}
            </button>
          );
        })}
      </div>
    </div>
  );
}
