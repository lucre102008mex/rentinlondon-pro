import { RefreshCw, Check, X, User } from "lucide-react";
import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";

const ReactivationsPage = () => {
    const [reactivations, setReactivations] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);

    const fetchReactivations = async () => {
        setLoading(true);
        const { data, error } = await supabase
            .from('v_reactivation_pendientes')
            .select('reactivation_id, lead_nombre, agente_asignado, estado')
            .order('created_at', { ascending: true });

        if (error) {
            console.error("Error fetching reactivations:", error);
        } else {
            setReactivations(data || []);
        }
        setLoading(false);
    };

    useEffect(() => {
        fetchReactivations();
    }, []);

    const handleAction = async (id: string, action: 'approve' | 'reject') => {
        // This is a placeholder since the actual update logic might vary
        // Typically it would update the 'estado' in the 'reactivation' table
        const { error } = await supabase
            .from('reactivations')
            .update({ estado: action === 'approve' ? 'aprobado' : 'rechazado' })
            .eq('id', id);

        if (error) {
            toast.error(`Error to ${action}: ` + error.message);
        } else {
            toast.success(`Succesfully ${action}ed!`);
            fetchReactivations();
        }
    };

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-2xl font-semibold text-foreground italic flex items-center gap-2">
                    <RefreshCw className="text-primary" /> Reactivation Queue
                </h1>
                <p className="text-sm text-muted-foreground mt-1">Review leads that the AI has detected as potentially interested again.</p>
            </div>

            <div className="bg-card border border-border rounded-lg overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                        <thead>
                            <tr className="border-b border-border text-muted-foreground text-xs">
                                <th className="text-left px-4 py-3 font-medium">Prospect</th>
                                <th className="text-left px-4 py-3 font-medium">Assigned Agent</th>
                                <th className="text-left px-4 py-3 font-medium">Status</th>
                                <th className="text-right px-4 py-3 font-medium">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-border">
                            {loading ? (
                                <tr>
                                    <td colSpan={4} className="px-4 py-10 text-center text-muted-foreground italic">
                                        Loading queue...
                                    </td>
                                </tr>
                            ) : reactivations.length === 0 ? (
                                <tr>
                                    <td colSpan={4} className="px-4 py-10 text-center text-muted-foreground italic">
                                        Queue is empty. No pending reactivations.
                                    </td>
                                </tr>
                            ) : (
                                reactivations.map((r, i) => (
                                    <tr key={i} className="hover:bg-accent/50 transition-colors">
                                        <td className="px-4 py-3 text-foreground font-medium flex items-center gap-2">
                                            <User className="h-3 w-3 text-primary" /> {r.lead_nombre || 'Unknown'}
                                        </td>
                                        <td className="px-4 py-3 text-muted-foreground font-semibold">{r.agente_asignado}</td>
                                        <td className="px-4 py-3">
                                            <span className="px-2 py-0.5 rounded-full bg-status-pending/20 text-status-pending text-[10px] font-bold uppercase border border-status-pending/30">
                                                {r.estado}
                                            </span>
                                        </td>
                                        <td className="px-4 py-3 text-right space-x-2">
                                            <button
                                                onClick={() => handleAction(r.reactivation_id, 'approve')}
                                                className="bg-primary hover:bg-primary/80 text-primary-foreground p-1.5 rounded-lg transition-colors border border-primary/20"
                                                title="Approve"
                                            >
                                                <Check className="h-4 w-4" />
                                            </button>
                                            <button
                                                onClick={() => handleAction(r.reactivation_id, 'reject')}
                                                className="bg-destructive/10 hover:bg-destructive/20 text-destructive p-1.5 rounded-lg transition-colors border border-destructive/20"
                                                title="Reject"
                                            >
                                                <X className="h-4 w-4" />
                                            </button>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );
};

export default ReactivationsPage;
