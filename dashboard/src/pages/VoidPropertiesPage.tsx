import { Building2, Clock, MapPin, PoundSterling, Plus, Trash2, Loader2, ArrowRight } from "lucide-react";
import { useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

const VoidPropertiesPage = () => {
    const queryClient = useQueryClient();
    const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
    const [newProperty, setNewProperty] = useState({
        direccion: "",
        zona: "",
        precio_mensual: ""
    });

    const { data: properties = [], isLoading } = useQuery({
        queryKey: ['void-properties'],
        queryFn: async () => {
            const { data, error } = await supabase
                .from('properties')
                .select('*')
                .eq('estado', 'void')
                .order('updated_at', { ascending: false });
            
            if (error) throw error;
            return data || [];
        }
    });

    const addMutation = useMutation({
        mutationFn: async (payload: any) => {
            const { error } = await supabase.from('properties').insert([{
                ...payload,
                estado: 'void',
                precio_mensual: parseFloat(payload.precio_mensual) || 0
            }]);
            if (error) throw error;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['void-properties'] });
            setIsAddDialogOpen(false);
            setNewProperty({ direccion: "", zona: "", precio_mensual: "" });
            toast.success("Property added as void");
        },
        onError: (error) => {
            toast.error("Error: " + error.message);
        }
    });

    const deleteMutation = useMutation({
        mutationFn: async (id: string) => {
            const { error } = await supabase.from('properties').delete().eq('id', id);
            if (error) throw error;
        },
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['void-properties'] });
            toast.success("Property removed");
        },
        onError: (error) => {
            toast.error("Error: " + error.message);
        }
    });

    const handleAddSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        if (!newProperty.direccion) {
            toast.error("Address is required");
            return;
        }
        addMutation.mutate(newProperty);
    };

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-semibold text-foreground italic flex items-center gap-2">
                        <Building2 className="text-primary" /> Void Properties
                    </h1>
                    <p className="text-sm text-muted-foreground mt-1 uppercase tracking-widest font-bold">Manage empty units & inventory</p>
                </div>

                <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
                    <DialogTrigger asChild>
                        <Button size="sm" className="bg-primary hover:bg-primary/90 text-primary-foreground flex items-center gap-2 shadow-lg hover:scale-105 transition-all">
                            <Plus className="h-4 w-4" /> New Property
                        </Button>
                    </DialogTrigger>
                    <DialogContent className="sm:max-w-[425px]">
                        <DialogHeader>
                            <DialogTitle className="flex items-center gap-2">
                                <Building2 className="h-5 w-5 text-primary" /> Add Void Property
                            </DialogTitle>
                        </DialogHeader>
                        <form onSubmit={handleAddSubmit} className="space-y-4 mt-4">
                            <div className="space-y-2">
                                <label className="text-[10px] font-black uppercase text-muted-foreground tracking-widest">Direction</label>
                                <div className="relative">
                                    <MapPin className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground/50" />
                                    <Input 
                                        className="pl-9 h-11 border-border/50 bg-background/50 focus:bg-background"
                                        value={newProperty.direccion}
                                        onChange={e => setNewProperty({...newProperty, direccion: e.target.value})}
                                        placeholder="Full address..."
                                    />
                                </div>
                            </div>
                            <div className="grid grid-cols-2 gap-4">
                                <div className="space-y-2">
                                    <label className="text-[10px] font-black uppercase text-muted-foreground tracking-widest">Zone</label>
                                    <Input 
                                        className="h-11 border-border/50 bg-background/50 focus:bg-background"
                                        value={newProperty.zona}
                                        onChange={e => setNewProperty({...newProperty, zona: e.target.value})}
                                        placeholder="e.g. EC1V"
                                    />
                                </div>
                                <div className="space-y-2">
                                    <label className="text-[10px] font-black uppercase text-muted-foreground tracking-widest">Monthly PCM</label>
                                    <div className="relative">
                                        <PoundSterling className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground/50" />
                                        <Input 
                                            type="number"
                                            className="pl-9 h-11 border-border/50 bg-background/50 focus:bg-background"
                                            value={newProperty.precio_mensual}
                                            onChange={e => setNewProperty({...newProperty, precio_mensual: e.target.value})}
                                            placeholder="2400"
                                        />
                                    </div>
                                </div>
                            </div>
                            <Button type="submit" className="w-full h-12 shadow-md hover:shadow-lg transition-all" disabled={addMutation.isPending}>
                                {addMutation.isPending ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <ArrowRight className="mr-2 h-4 w-4" />}
                                Add to Void List
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
                                <th className="text-left px-6 py-4 font-black uppercase tracking-widest">Direction</th>
                                <th className="text-left px-6 py-4 font-black uppercase tracking-widest">Zone</th>
                                <th className="text-left px-6 py-4 font-black uppercase tracking-widest">Price</th>
                                <th className="text-left px-6 py-4 font-black uppercase tracking-widest">Days Void</th>
                                <th className="text-right px-6 py-4 font-black uppercase tracking-widest">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-border">
                            {isLoading ? (
                                <tr>
                                    <td colSpan={5} className="px-6 py-12 text-center text-muted-foreground italic">
                                        <Loader2 className="h-10 w-10 animate-spin mx-auto mb-4 text-primary/40" />
                                        <p className="font-medium">Loading database...</p>
                                    </td>
                                </tr>
                            ) : properties.length === 0 ? (
                                <tr>
                                    <td colSpan={5} className="px-6 py-12 text-center text-muted-foreground italic">
                                        <Building2 className="h-12 w-12 mx-auto mb-4 text-muted-foreground/20" />
                                        <p>No void properties found in database.</p>
                                    </td>
                                </tr>
                            ) : (
                                properties.map((p, i) => {
                                    const updatedAt = p.updated_at || p.created_at;
                                    const daysVoid = updatedAt ? Math.floor((Date.now() - new Date(updatedAt).getTime()) / (1000 * 60 * 60 * 24)) : 0;
                                    return (
                                        <tr key={p.id || i} className="hover:bg-accent/20 transition-all group">
                                            <td className="px-6 py-4 text-foreground font-bold flex items-center gap-3">
                                                <div className="h-8 w-8 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center">
                                                    <MapPin className="h-4 w-4 text-primary" />
                                                </div>
                                                <span className="max-w-[300px] truncate">{p.direccion || '—'}</span>
                                            </td>
                                            <td className="px-6 py-4">
                                                <span className="px-2 py-1 rounded bg-secondary/50 text-secondary-foreground text-[10px] font-black uppercase border border-border">
                                                    {p.zona || '—'}
                                                </span>
                                            </td>
                                            <td className="px-6 py-4 text-foreground font-mono font-bold">
                                                <span className="flex items-center gap-1 text-primary">
                                                    <PoundSterling className="h-3 w-3" />
                                                    {p.precio_mensual?.toLocaleString() || '—'}
                                                </span>
                                            </td>
                                            <td className="px-6 py-4">
                                                <div className="flex items-center gap-2">
                                                    <div className={`h-2 w-2 rounded-full ${daysVoid > 14 ? 'bg-destructive animate-pulse' : 'bg-status-pending'}`} />
                                                    <span className="font-mono text-muted-foreground">{daysVoid}d</span>
                                                </div>
                                            </td>
                                            <td className="px-6 py-4 text-right">
                                                <button
                                                    onClick={() => {
                                                        if(confirm("Eliminar propiedad de la lista?")) deleteMutation.mutate(p.id);
                                                    }}
                                                    className="bg-muted hover:bg-destructive hover:text-white p-2 rounded-lg transition-all border border-border shadow-sm hover:scale-110 active:scale-95 text-muted-foreground"
                                                    title="Remove"
                                                >
                                                    <Trash2 className="h-4 w-4" />
                                                </button>
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


