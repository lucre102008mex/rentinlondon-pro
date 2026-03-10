import { Building2, Clock, MapPin, PoundSterling } from "lucide-react";
import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";

const VoidPropertiesPage = () => {
    const [properties, setProperties] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchVoidProperties = async () => {
            const { data, error } = await supabase
                .from('properties')
                .select('direccion, zona, precio_mensual, updated_at')
                .eq('estado', 'void')
                .order('updated_at', { ascending: true });

            if (error) {
                console.error("Error fetching void properties:", error);
            } else {
                setProperties(data || []);
            }
            setLoading(false);
        };

        fetchVoidProperties();
    }, []);

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-2xl font-semibold text-foreground italic flex items-center gap-2">
                    <Building2 className="text-primary" /> Void Properties
                </h1>
                <p className="text-sm text-muted-foreground mt-1">Properties currently empty and awaiting tenants.</p>
            </div>

            <div className="bg-card border border-border rounded-lg overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                        <thead>
                            <tr className="border-b border-border text-muted-foreground text-xs">
                                <th className="text-left px-4 py-3 font-medium">Direction</th>
                                <th className="text-left px-4 py-3 font-medium">Zone</th>
                                <th className="text-left px-4 py-3 font-medium">Monthly Price</th>
                                <th className="text-left px-4 py-3 font-medium">Days Void</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-border">
                            {loading ? (
                                <tr>
                                    <td colSpan={4} className="px-4 py-10 text-center text-muted-foreground italic">
                                        Loading database...
                                    </td>
                                </tr>
                            ) : properties.length === 0 ? (
                                <tr>
                                    <td colSpan={4} className="px-4 py-10 text-center text-muted-foreground italic">
                                        Great news! No void properties found.
                                    </td>
                                </tr>
                            ) : (
                                properties.map((p, i) => {
                                    const daysVoid = Math.floor((Date.now() - new Date(p.updated_at).getTime()) / (1000 * 60 * 60 * 24));
                                    return (
                                        <tr key={i} className="hover:bg-accent/50 transition-colors">
                                            <td className="px-4 py-3 text-foreground font-medium flex items-center gap-2">
                                                <MapPin className="h-3 w-3 text-muted-foreground" /> {p.direccion || '—'}
                                            </td>
                                            <td className="px-4 py-3 text-muted-foreground">{p.zona || '—'}</td>
                                            <td className="px-4 py-3 text-foreground font-mono">
                                                <PoundSterling className="h-3 w-3 inline mr-1 text-primary" />{p.precio_mensual || '—'}
                                            </td>
                                            <td className="px-4 py-3 text-muted-foreground font-mono flex items-center gap-2">
                                                <Clock className="h-3 w-3 text-status-pending" /> {daysVoid}d
                                            </td>
                                        </tr>
                                    );
                                })
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
};

export default VoidPropertiesPage;
