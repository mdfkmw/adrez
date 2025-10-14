import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import ReservationPage from './ReservationPage';
import BackupPage from './pages/BackupPage';
import BlacklistAdmin from './components/BlacklistAdmin';
import PassengerReport from './components/PassengerReport';
import AdminPage from './pages/AdminPage';
import ReportsPage from './pages/ReportsPage';
import RouteEditorPage from './pages/RouteEditorPage';
import PeopleList from './pages/PeopleList';

function App() {
  return (
    <Router>
      <div className="p-4 bg-gray-100 flex gap-6">
        <Link to="/" className="text-blue-600 hover:underline">Rezervări</Link>
        <Link to="/backup" className="text-blue-600 hover:underline">Backupuri</Link>
        <Link to="/admin/blacklist" className="text-blue-600 hover:underline">Blacklist</Link>
        <Link to="/admin" className="text-blue-600 hover:underline">Administrare</Link>
        <Link to="/admin/reports" className="text-blue-600 hover:underline">Rapoarte</Link>
        <Link to="/pasageri" className="text-blue-600 hover:underline">Pasageri</Link>
        {/* <Link to="/admin/route-editor" className="text-blue-600 hover:underline">Editor traseu</Link> */}


      </div>

      <Routes>
        <Route path="/" element={<ReservationPage />} />
        <Route path="/backup" element={<BackupPage />} />
        <Route path="/admin/blacklist" element={<BlacklistAdmin />} />
        <Route path="/raport/:personId" element={<PassengerReport />} />
        <Route path="/admin" element={<AdminPage />} />
        <Route path="/admin/reports" element={<ReportsPage />} />
        <Route path="/admin/routes/:id/edit" element={<RouteEditorPage />} />
        <Route path="/pasageri" element={<PeopleList />} />
      </Routes>
    </Router>
  );
}

export default App;
