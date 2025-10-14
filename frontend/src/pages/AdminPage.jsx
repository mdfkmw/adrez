// File: AdminPage.jsx
import React, { useState } from 'react';
import AdminDrivers from './AdminDrivers';
import AdminRuteTab from './AdminRuteTab';
import StationsPage from './StationsPage';
import DiscountTypeAdmin from './AdminDiscountType';
import DiscountAppliesTab from './DiscountAppliesTab';
import AdminPriceLists from './AdminPriceLists';
import AdminEmployees from './AdminEmployees';
//import AdminScheduleExceptions from './AdminScheduleExceptions';
import AdminDisabledSchedules from './AdminDisabledSchedules';

export default function AdminPage() {
  const [tab, setTab] = useState('drivers');

  const tabButton = (key, label) => (
    <button
      className={
        tab === key
          ? 'bg-blue-600 text-white px-3 py-1 rounded'
          : 'bg-gray-200 px-3 py-1 rounded'
      }
      onClick={() => setTab(key)}
    >
      {label}
    </button>
  );

  return (
    <div className="p-4">
      {/* --- TAB BAR ---------------------------------------------------- */}
      <div className="flex flex-wrap gap-2 mb-4">
        {tabButton('drivers', 'Șoferi')}
        {tabButton('rute', 'Rute')}
        {tabButton('stations', 'Stații')}
        {tabButton('discounts', 'Tipuri Discount')}
        {tabButton('applies', 'Se aplică la')}
        {tabButton('prices', 'Liste prețuri')}
        {tabButton('employees', 'Angajați')}
        {/* {tabButton('exceptions', 'Excepții curse')} */}
        {tabButton('disabled', 'Curse Dezactivate')}
      </div>

      {/* --- TAB CONTENT ------------------------------------------------ */}
      {tab === 'drivers'    && <AdminDrivers />}
      {tab === 'rute'       && <AdminRuteTab />}
      {tab === 'stations'   && <StationsPage />}
      {tab === 'discounts'  && <DiscountTypeAdmin />}
      {tab === 'applies'    && <DiscountAppliesTab />}
      {tab === 'prices'     && <AdminPriceLists />}
      {tab === 'employees'  && <AdminEmployees />}
      {/* {tab === 'exceptions' && <AdminScheduleExceptions />} */}
      {tab === 'disabled'   && <AdminDisabledSchedules />}
    </div>
  );
}
