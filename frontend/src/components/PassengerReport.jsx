import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';

export default function PassengerReport() {
    const { personId } = useParams();
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetch(`/api/people/${personId}/report`)
            .then(res => res.json())
            .then(json => {
                setData(json);
                setLoading(false);
            })
            .catch(err => {
                console.error('Eroare la fetch raport:', err);
                setLoading(false);
            });
    }, [personId]);

    if (loading) return <div className="p-4">Se încarcă...</div>;
    if (!data) return <div className="p-4 text-red-500">Eroare la încărcare</div>;

    const {
        personName = '',
        reservations = [],
        noShows = [],
        blacklist
    } = data;

    return (
        <div className="p-6 max-w-4xl mx-auto">
            <h1 className="text-xl font-bold mb-4">
                Raport pasager ID #{personId}
                {personName && ` - ${personName}`}
            </h1>


            {data.blacklist && (
                <div className="bg-red-100 border border-red-400 text-red-700 p-4 rounded mb-6">
                    🚫 În blacklist: {data.blacklist.reason} <br />
                    <span className="text-sm italic">Adăugat la: {new Date(data.blacklist.created_at).toLocaleString()}</span>
                </div>
            )}

            <section className="mb-6">
                <h2 className="text-lg font-semibold mb-2">📅 Rezervări</h2>
                {reservations.length === 0 ? (
                    <div className="text-gray-500">Nicio rezervare găsită.</div>
                ) : (
                    <table className="w-full text-sm border-collapse border">
                        <thead>
                            <tr className="bg-gray-100">
                                <th className="p-2 border">Data călătoriei<br />(Rezervare la)</th>
                                <th className="p-2 border">Traseu</th>
                                <th className="p-2 border">Ora cursă</th>
                                <th className="p-2 border">Segment</th>
                                <th className="p-2 border">Loc</th>
                            </tr>
                        </thead>
                        <tbody>
                            {reservations.map((r, index) => {
                                const isNoShow = noShows.some(n =>
                                    n.date === r.date &&
                                    n.time === r.time &&
                                    n.board_at === r.board_at &&
                                    n.exit_at === r.exit_at
                                );
                                return (
                                    <tr
                                        key={index}
                                        style={{ backgroundColor: isNoShow ? '#ffe6e6' : 'white' }}
                                    >
                                        <td className="p-2 border">
                                            {new Date(r.date).toLocaleDateString('ro-RO')}
                                            <br />
                                            <span className="text-xs text-gray-500">
                                                {r.reservation_time
                                                    ? new Date(r.reservation_time).toLocaleTimeString('ro-RO', {
                                                        hour: '2-digit',
                                                        minute: '2-digit',
                                                        timeZone: 'Europe/Bucharest'
                                                    })
                                                    : ''
                                                }
                                            </span>
                                        </td>
                                        <td className="p-2 border">{r.route_name}</td>
                                        <td className="p-2 border">{r.time.substring(0, 5)}</td>
                                        <td className="p-2 border">{r.board_at} → {r.exit_at}</td>
                                        <td className="p-2 border">{r.seat_label}</td>

                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                )}
            </section>





            <div className="mt-6">
                <Link to="/" className="text-blue-600 hover:underline">← Înapoi la rezervări</Link>
            </div>
        </div>
    );
}
