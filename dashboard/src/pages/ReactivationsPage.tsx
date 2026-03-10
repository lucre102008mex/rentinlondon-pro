import { RefreshCw, Check, X, User, Plus, Loader2, Trash2 } from "lucide-react";
import { useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";

const ReactivationsPage = () => {
    const queryClient = useQueryClient();
    const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
    const [newReactivation, setNewReactivation] = useState({
        lead_id: "",
        agente_asignado: "ivy",
        mensaje_propuesto: ""
    });

    const { data: reactivations = [], isLoading } = useQuery({
        queryKey: ['reactivations'],
        queryFn: async () => {
            const { data, error } = await supabase
                .from('v_reactivation_pendientes')
                .select('reactivation_id, lead_nombre, agente_asignado, estado')
                .order('created_at', { ascending: true });
            
            if (error) throw error;
            return data || [];
        }
    });

    const { data: leads = [] } = useQuery({
        queryKey: ['leads-simple'],
        queryFn: async () => {
            const { data, error } = await supabase
                .from('leads')
                .select('id, nombre')
                .limit(50);
            if (error) throw error;
            return data || [];
        },
        enabled: isAddDialogOpen
    });

    const addMutation = useMutation({
        mutationFn: async (payload: any) => {
            const { error } = await supabase.from('reactivation').insert([payload]);
            if (error) throw error;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['reactivations'] });
            setIsAddDialogOpen(false);
            setNewReactivation({ lead_id: "", agente_asignado: "ivy", mensaje_propuesto: "" });
            toast.success("Manual reactivation added");
        },
        onError: (error) => {
            toast.error("Error: " + error.message);
        }
    });

    const actionMutation = useMutation({
        mutationFn: async ({ id, action }: { id: string, action: 'approve' | 'reject' }) => {
            const { error } = await supabase
                .from('reactivation')
                .update({ estado: action === 'approve' ? 'aprobado' : 'rechazado' })
                .eq('id', id);
            if (error) throw error;
        },
        onSuccess: (_, variables) => {
            toast.success(`Successfully ${variables.action}ed!`);
            queryClient.invalidateQueries({ queryKey: ['reactivations'] });
        },
        onError: (error, variables) => {
            toast.error(`Error to ${variables.action}: ` + error.message);
        }
    });

    const deleteMutation = useMutation({
        mutationFn: async (id: string) => {
            const { error } = await supabase.from('reactivation').delete().eq('id', id);
            if (error) throw error;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['reactivations'] });
            toast.success("Reactivation deleted");
        },
        onError: (error) => {
            toast.error("Error: " + error.message);
        }
    });

    const handleAddSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        if (!newReactivation.lead_id) {
            toast.error("Please select a lead");
            return;
        }
        addMutation.mutate(newReactivation);
    };

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-semibold text-foreground italic flex items-center gap-2">
                        <RefreshCw className="text-primary" /> Reactivation Queue
                    </h1>
                    <p className="text-sm text-muted-foreground mt-1 uppercase tracking-widest font-bold">Review AI-detected opportunities</p>
                </div>
                
                <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
                    <DialogTrigger asChild>
                        <Button size="sm" className="bg-primary hover:bg-primary/90 text-primary-foreground flex items-center gap-2 shadow-lg hover:scale-105 transition-all">
                            <Plus className="h-4 w-4" /> Add Manual
                        </Button>
                    </DialogTrigger>
                    <DialogContent className="sm:max-w-[425px]">
                        <DialogHeader>
                            <DialogTitle>Manual Reactivation</DialogTitle>
                        </DialogHeader>
                        <form onSubmit={handleAddSubmit} className="space-y-4 mt-4">
                            <div className="space-y-2">
                                <label className="text-xs font-semibold">Select Lead</label>
                                <Select value={newReactivation.lead_id} onValueChange={v => setNewReactivation({...newReactivation, lead_id: v})}>
                                    <SelectTrigger>
                                        <SelectValue placeholder="Search prospects..." />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {leads.map(l => (
                                            <SelectItem key={l.id} value={l.id}>{l.nombre}</SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </div>
                            <div className="space-y-2">
                                <label className="text-xs font-semibold">Assign Agent</label>
                                <Select value={newReactivation.agente_asignado} onValueChange={v => setNewReactivation({...newReactivation, agente_asignado: v})}>
                                    <SelectTrigger>
                                        <SelectValue />
                                    </SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="alex">Alex</SelectItem>
                                        <SelectItem value="ivy">Ivy</SelectItem>
                                        <SelectItem value="rose">Rose</SelectItem>
                                        <SelectItem value="salo">Salo</SelectItem>
                                        <SelectItem value="jeanette">Jeanette</SelectItem>
                                    </SelectContent>
                                </Select>
                            </div>
                            <div className="space-y-2">
                                <label className="text-xs font-semibold">Proposed Message (Optional)</label>
                                <Textarea 
                                    className="min-h-[100px]"
                                    value={newReactivation.mensaje_propuesto}
                                    onChange={e => setNewReactivation({...newReactivation, mensaje_propuesto: e.target.value})}
                                    placeholder="He visto que antes buscabas en..."
                                />
                            </div>
                            <Button type="submit" className="w-full" disabled={addMutation.isPending}>
                                {addMutation.isPending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                                Create Reactivation
                            </Button>
                        </form>
                    </DialogContent>
                </Dialog>
            </div>

            <div className="bg-card border border-border rounded-xl overflow-hidden shadow-xl">
                <div className="overflow-x-auto">
                    <table className="w-full text-sm">
                        <thead>
                            <tr className="border-b border-border text-muted-foreground text-xs bg-muted/30">
                                <th className="text-left px-6 py-4 font-black uppercase tracking-widest">Prospect</th>
                                <th className="text-left px-6 py-4 font-black uppercase tracking-widest">Agente</th>
                                <th className="text-left px-6 py-4 font-black uppercase tracking-widest">Estado</th>
                                <th className="text-right px-6 py-4 font-black uppercase tracking-widest">Acciones</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-border">
                            {isLoading ? (
                                <tr>
                                    <td colSpan={4} className="px-4 py-12 text-center text-muted-foreground italic">
                                        <Loader2 className="h-10 w-10 animate-spin mx-auto mb-4 text-primary/40" />
                                        <p className="font-medium">Loading queue...</p>
                                    </td>
                                </tr>
                            ) : reactivations.length === 0 ? (
                                <tr>
                                    <td colSpan={4} className="px-4 py-12 text-center text-muted-foreground italic">
                                        <RefreshCw className="h-12 w-12 mx-auto mb-4 text-muted-foreground/20" />
                                        <p>Queue is empty. No pending reactivations.</p>
                                    </td>
                                </tr>
                            ) : (
                                reactivations.map((r, i) => (
                                    <tr key={i} className="hover:bg-accent/20 transition-all group">
                                        <td className="px-6 py-4 text-foreground font-bold flex items-center gap-3">
                                            <div className="h-8 w-8 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center shadow-inner">
                                                <User className="h-4 w-4 text-primary" />
                                            </div>
                                            {r.lead_nombre || 'Unknown Lead'}
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className="text-[11px] font-black text-muted-foreground/80 bg-secondary/50 px-2 py-1 rounded-md border border-border tracking-tighter uppercase">{r.agente_asignado}</span>
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className="px-3 py-1 rounded-full bg-status-pending/10 text-status-pending text-[10px] font-black uppercase border border-status-pending/30 shadow-sm">
                                                {r.estado}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4 text-right space-x-2">
                                            <button
                                                onClick={() => actionMutation.mutate({ id: r.reactivation_id, action: 'approve' })}
                                                disabled={actionMutation.isPending}
                                                className="bg-primary hover:bg-primary/90 text-primary-foreground p-2 rounded-lg transition-all border border-primary/20 shadow-md disabled:opacity-50 hover:scale-110 active:scale-95"
                                                title="Approve"
                                            >
                                                <Check className="h-4 w-4" />
                                            </button>
                                            <button
                                                onClick={() => actionMutation.mutate({ id: r.reactivation_id, action: 'reject' })}
                                                disabled={actionMutation.isPending}
                                                className="bg-destructive/10 hover:bg-destructive/20 text-destructive p-2 rounded-lg transition-all border border-destructive/20 shadow-sm disabled:opacity-50 hover:scale-110 active:scale-95"
                                                title="Reject"
                                            >
                                                <X className="h-4 w-4" />
                                            </button>
                                            <button
                                                onClick={() => {
                                                    if(confirm("Eliminar esta entrada?")) deleteMutation.mutate(r.reactivation_id);
                                                }}
                                                className="bg-muted hover:bg-destructive hover:text-destructive-foreground p-2 rounded-lg transition-all border border-border shadow-sm hover:scale-110 active:scale-95 text-muted-foreground"
                                                title="Delete"
                                            >
                                                <Trash2 className="h-4 w-4" />
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


