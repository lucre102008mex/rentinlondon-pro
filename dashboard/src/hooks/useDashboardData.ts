import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

export const useDashboardData = () => {
    // 1. Leads Count and Stats
    const { data: leadsStats, isLoading: isLoadingLeads } = useQuery({
        queryKey: ["leads-stats"],
        queryFn: async () => {
            const { data: leads, error, count } = await supabase
                .from("leads")
                .select("*", { count: "exact" });

            if (error) throw error;

            const hotLeads = leads?.filter(l => (l.urgency_score || 0) >= 8).length || 0;

            return {
                totalLeads: count || 0,
                hotLeads,
                leadsList: leads || []
            };
        }
    });

    // 2. Recent Interactions (Activity Feed)
    const { data: activityFeed, isLoading: isLoadingActivity } = useQuery({
        queryKey: ["activity-feed"],
        queryFn: async () => {
            const { data, error } = await supabase
                .from("interactions")
                .select("created_at, contenido, agente, tipo, leads(nombre)")
                .order("created_at", { ascending: false })
                .limit(10);

            if (error) throw error;

            return (data as any[]).map(item => ({
                time: formatTimeAgo(new Date(item.created_at)),
                action: `${item.agente} ${item.tipo === 'mensaje_saliente' ? 'responded to' : 'received from'} lead ${item.leads?.nombre || 'Unknown'}`,
                status: item.tipo === 'mensaje_saliente' ? "active" : "pending"
            }));
        }
    });

    // 3. Agent Logs (Heartbeat/Activity)
    const { data: agentActivity, isLoading: isLoadingAgents } = useQuery({
        queryKey: ["agent-logs"],
        queryFn: async () => {
            const { data, error, count } = await supabase
                .from("agent_logs")
                .select("*", { count: "exact" })
                .gte("created_at", new Date(new Date().setHours(0, 0, 0, 0)).toISOString());

            if (error) throw error;
            return {
                actionsToday: count || 0,
                logs: data || []
            };
        }
    });

    return {
        leadsStats,
        activityFeed,
        agentActivity,
        isLoading: isLoadingLeads || isLoadingActivity || isLoadingAgents
    };
};

function formatTimeAgo(date: Date) {
    const diff = Math.floor((new Date().getTime() - date.getTime()) / 1000);
    if (diff < 60) return `${diff}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    return `${Math.floor(diff / 3600)}h ago`;
}
