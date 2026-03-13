import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

interface Followup {
  id: string;
  lead_id: string;
  nombre: string;
  telefono: string;
  canal_origen: string;
  zona_preferida: string;
  presupuesto_max: number;
  fecha_mudanza: string;
  dias_antes: number;
  fecha_seguimiento: string;
  agente_asignado: string;
  scl_score: number;
  lead_status: string;
  followup_estado: string;
}

interface Task {
  id: string;
  lead_id: string;
  nombre: string;
  telefono: string;
  canal_origen: string;
  zona_preferida: string;
  presupuesto_max: number;
  scl_score: number;
  lead_status: string;
  agente_asignado: string;
  tipo_tarea: string;
  titulo: string;
  descripcion: string;
  fecha_programada: string;
  hora_programada: string;
  estado: string;
  prioridad: string;
}

export function useFollowups() {
  return useQuery({
    queryKey: ["followups-hoy"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("v_followups_hoy")
        .select("*")
        .order("dias_antes", { ascending: true });
      
      if (error) throw error;
      return data as Followup[];
    },
    refetchInterval: 60000, // Refetch cada minuto
  });
}

export function useTasks() {
  return useQuery({
    queryKey: ["tasks-hoy"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("v_tasks_hoy")
        .select("*")
        .order("prioridad", { ascending: false });
      
      if (error) throw error;
      return data as Task[];
    },
    refetchInterval: 60000,
  });
}

export function useFollowupsPendientes() {
  return useQuery({
    queryKey: ["followups-pendientes"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("lead_followups")
        .select(`
          id,
          lead_id,
          agente_asignado,
          fecha_mudanza_original,
          dias_antes,
          fecha_seguimiento,
          tipo_seguimiento,
          estado,
          leads (nombre, telefono, zona_preferida, presupuesto_max, scl_score)
        `)
        .eq("estado", "pendiente")
        .lte("fecha_seguimiento", new Date().toISOString().split("T")[0])
        .order("fecha_seguimiento", { ascending: true });
      
      if (error) throw error;
      return data;
    },
    refetchInterval: 60000,
  });
}

export function useAgenteDashboard(agente: string) {
  return useQuery({
    queryKey: ["agente-dashboard", agente],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("v_agente_dashboard")
        .select("*")
        .eq("agente", agente)
        .single();
      
      if (error) throw error;
      return data;
    },
    enabled: !!agente,
    refetchInterval: 60000,
  });
}

export function useCompleteTask() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: async ({ taskId, resultado, notas }: { taskId: string; resultado?: string; notas?: string }) => {
      const { error } = await supabase.rpc("fn_complete_task", {
        p_task_id: taskId,
        p_resultado: resultado,
        p_notas: notas,
      });
      
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tasks-hoy"] });
      queryClient.invalidateQueries({ queryKey: ["followups-hoy"] });
    },
  });
}

export function useMarkFollowupContactado() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: async ({ followupId, resultado, notas }: { followupId: string; resultado?: string; notas?: string }) => {
      const { error } = await supabase.rpc("fn_mark_followup_contactado", {
        p_followup_id: followupId,
        p_resultado: resultado,
        p_notas: notas,
      });
      
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["followups-hoy"] });
      queryClient.invalidateQueries({ queryKey: ["followups-pendientes"] });
    },
  });
}