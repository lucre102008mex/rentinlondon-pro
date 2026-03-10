import { useState } from "react";
import { Search, User, MessageCircle, Phone, Zap, Calendar, DollarSign, Bot, Filter } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import StatusDot from "@/components/StatusDot";

type FilterType = "All" | "Hot Leads" | "Bookings" | "Warm" | "Cold";

const filterTabs: FilterType[] = ["All", "Hot Leads", "Bookings", "Warm", "Cold"];

const filterConfig: Record<FilterType, { label: string; color: string }> = {
    "All": { label: "All", color: "bg-secondary text-secondary-foreground" },
    "Hot Leads": { label: "🔥 Hot", color: "bg-priority-urgent/15 text-priority-urgent border border-priority-urgent/30" },
    "Bookings": { label: "📅 Bookings", color: "bg-primary/15 text-primary border border-primary/30" },
    "Warm": { label: "🌡 Warm", color: "bg-status-pending/15 text-status-pending border border-status-pending/30" },
    "Cold": { label: "❄️ Cold", color: "bg-secondary text-muted-foreground border border-border" },
};

const tierBadge = (score: number) => {
    if (score >= 8) return { label: "HOT", cls: "bg-priority-urgent/20 text-priority-urgent border-priority-urgent/40" };
    if (score >= 5) return { label: "WARM", cls: "bg-status-pending/20 text-status-pending border-status-pending/40" };
    return { label: "COLD", cls: "bg-secondary text-muted-foreground border-border" };
};

const ContactsPage = () => {
    const [search, setSearch] = useState("");
    const [activeFilter, setActiveFilter] = useState<FilterType>("All");

    const { data: leads = [], isLoading } = useQuery({
        queryKey: ["contacts-leads"],
        queryFn: async () => {
            const { data, error } = await supabase
                .from("leads")
                .select("id, nombre, telefono, presupuesto_max, urgency_score, asignado_a, estado, created_at, booking_confirmed")
                .order("urgency_score", { ascending: false });
            if (error) throw error;
            return data || [];
        }
    });

    const filtered = leads.filter((lead: any) => {
        const score = lead.urgency_score || 0;
        const nombre = (lead.nombre || "").toLowerCase();
        const tel = (lead.telefono || "").toLowerCase();
        const matchesSearch = nombre.includes(search.toLowerCase()) || tel.includes(search.toLowerCase());

        if (!matchesSearch) return false;

        switch (activeFilter) {
            case "Hot Leads": return score >= 8;
            case "Bookings": return lead.booking_confirmed === true;
            case "Warm": return score >= 5 && score < 8;
            case "Cold": return score < 5;
            default: return true;
        }
    });

    const counts = {
        "All": leads.length,
        "Hot Leads": leads.filter((l: any) => (l.urgency_score || 0) >= 8).length,
        "Bookings": leads.filter((l: any) => l.booking_confirmed === true).length,
        "Warm": leads.filter((l: any) => { const s = l.urgency_score || 0; return s >= 5 && s < 8; }).length,
        "Cold": leads.filter((l: any) => (l.urgency_score || 0) < 5).length,
    };

    return (
        <div className="space-y-6">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-semibold text-foreground">Contacts / CRM</h1>
                    <p className="text-sm text-muted-foreground mt-1">Leads activos del pipeline — datos en tiempo real desde Supabase</p>
                </div>
                <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-border bg-card">
                    <StatusDot status={isLoading ? "pending" : "active"} />
                    <span className="text-xs text-muted-foreground">{isLoading ? "Cargando..." : `${leads.length} leads`}</span>
                </div>
            </div>

            {/* Search + Filter Bar */}
            <div className="flex flex-col sm:flex-row gap-3">
                <div className="flex-1 relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <input
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        placeholder="Buscar por nombre o teléfono..."
                        className="w-full bg-secondary border border-border rounded-lg pl-9 pr-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-primary"
                    />
                </div>
                <div className="flex items-center gap-1.5 bg-card border border-border rounded-lg px-2 py-1">
                    <Filter className="h-3.5 w-3.5 text-muted-foreground ml-1" />
                    {filterTabs.map(tab => (
                        <button
                            key={tab}
                            onClick={() => setActiveFilter(tab)}
                            className={`text-[11px] px-2.5 py-1 rounded-md font-medium transition-colors ${activeFilter === tab
                                ? filterConfig[tab].color + " font-bold"
                                : "text-muted-foreground hover:text-foreground"
                                }`}
                        >
                            {filterConfig[tab].label}
                            <span className="ml-1 opacity-60">({counts[tab]})</span>
                        </button>
                    ))}
                </div>
            </div>

            {/* Cards Grid */}
            {isLoading ? (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {[...Array(6)].map((_, i) => (
                        <div key={i} className="bg-card border border-border rounded-lg p-4 animate-pulse h-40" />
                    ))}
                </div>
            ) : filtered.length === 0 ? (
                <div className="text-center py-16 text-muted-foreground">
                    <User className="h-10 w-10 mx-auto mb-3 opacity-30" />
                    <p className="text-sm">No se encontraron leads con ese filtro.</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {filtered.map((lead: any) => {
                        const score = lead.urgency_score || 0;
                        const badge = tierBadge(score);
                        return (
                            <div
                                key={lead.id}
                                className="bg-card border border-border rounded-xl p-4 hover:border-primary/30 hover:shadow-md transition-all duration-200 group"
                            >
                                {/* Top row */}
                                <div className="flex items-start justify-between mb-3">
                                    <div className="flex items-center gap-3">
                                        <div className="w-9 h-9 rounded-full bg-secondary flex items-center justify-center group-hover:bg-primary/10 transition-colors">
                                            <User className="h-4 w-4 text-muted-foreground" />
                                        </div>
                                        <div>
                                            <h3 className="text-sm font-medium text-foreground leading-tight">{lead.nombre || "—"}</h3>
                                            <p className="text-[10px] text-muted-foreground font-mono">{lead.id?.substring(0, 8)}</p>
                                        </div>
                                    </div>
                                    <span className={`text-[9px] font-bold px-2 py-0.5 rounded-full border ${badge.cls}`}>
                                        {badge.label}
                                    </span>
                                </div>

                                {/* Details */}
                                <div className="space-y-1.5 mb-3">
                                    {lead.telefono && (
                                        <div className="flex items-center gap-2">
                                            <MessageCircle className="h-3 w-3 text-muted-foreground shrink-0" />
                                            <span className="text-xs text-foreground/80 font-mono">{lead.telefono}</span>
                                        </div>
                                    )}
                                    {lead.presupuesto_max && (
                                        <div className="flex items-center gap-2">
                                            <DollarSign className="h-3 w-3 text-muted-foreground shrink-0" />
                                            <span className="text-xs text-foreground/80">£{lead.presupuesto_max?.toLocaleString()}/mo</span>
                                        </div>
                                    )}
                                    {lead.asignado_a && (
                                        <div className="flex items-center gap-2">
                                            <Bot className="h-3 w-3 text-muted-foreground shrink-0" />
                                            <span className="text-xs text-muted-foreground">{lead.asignado_a}</span>
                                        </div>
                                    )}
                                    {lead.booking_confirmed && (
                                        <div className="flex items-center gap-2">
                                            <Calendar className="h-3 w-3 text-primary shrink-0" />
                                            <span className="text-xs text-primary font-medium">Booking confirmado</span>
                                        </div>
                                    )}
                                </div>

                                {/* Score Bar */}
                                <div className="space-y-1">
                                    <div className="flex items-center justify-between">
                                        <span className="text-[10px] text-muted-foreground flex items-center gap-1">
                                            <Zap className="h-2.5 w-2.5" /> Urgency Score
                                        </span>
                                        <span className="text-[10px] font-mono font-bold text-foreground">{score}/10</span>
                                    </div>
                                    <div className="h-1.5 rounded-full bg-secondary overflow-hidden">
                                        <div
                                            className={`h-full rounded-full transition-all ${score >= 8 ? "bg-priority-urgent" : score >= 5 ? "bg-status-pending" : "bg-muted-foreground"}`}
                                            style={{ width: `${score * 10}%` }}
                                        />
                                    </div>
                                </div>

                                {/* Estado tag */}
                                {lead.estado && (
                                    <div className="mt-3 pt-3 border-t border-border">
                                        <span className="text-[10px] bg-secondary text-secondary-foreground px-2 py-0.5 rounded font-mono">{lead.estado}</span>
                                    </div>
                                )}
                            </div>
                        );
                    })}
                </div>
            )}
        </div>
    );
};

export default ContactsPage;
