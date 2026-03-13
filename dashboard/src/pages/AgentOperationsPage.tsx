import { Bell, CheckCircle, Clock, AlertTriangle, Users, Calendar, MessageSquare, TrendingUp } from "lucide-react";
import StatusDot from "@/components/StatusDot";
import { useFollowups, useTasks, useCompleteTask, useMarkFollowupContactado } from "@/hooks/useTasksAndFollowups";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { useState } from "react";
import { toast } from "sonner";

const AgentOperations = () => {
  const { data: followups, isLoading: followupsLoading } = useFollowups();
  const { data: tasks, isLoading: tasksLoading } = useTasks();
  const completeTask = useCompleteTask();
  const markFollowup = useMarkFollowupContactado();
  const [selectedAgent, setSelectedAgent] = useState<string | "all">("all");

  const agents = ["ivy", "rose", "salo", "jeanette"];

  const filteredFollowups = selectedAgent === "all" 
    ? followups 
    : followups?.filter(f => f.agente_asignado === selectedAgent);

  const filteredTasks = selectedAgent === "all"
    ? tasks
    : tasks?.filter(t => t.agente_asignado === selectedAgent);

  const handleCompleteTask = async (taskId: string) => {
    try {
      await completeTask.mutateAsync({ taskId, resultado: "Completado" });
      toast.success("Tarea marcada como completada");
    } catch (error) {
      toast.error("Error al completar tarea");
    }
  };

  const handleMarkFollowupContacted = async (followupId: string) => {
    try {
      await markFollowup.mutateAsync({ followupId, resultado: "Contactado" });
      toast.success("Followup marcado como contactado");
    } catch (error) {
      toast.error("Error al actualizar followup");
    }
  };

  const getAgentColor = (agent: string) => {
    const colors: Record<string, string> = {
      ivy: "bg-emerald-500",
      rose: "bg-pink-500",
      salo: "bg-amber-500",
      jeanette: "bg-purple-500",
    };
    return colors[agent] || "bg-gray-500";
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case "urgente": return "bg-red-500";
      case "alta": return "bg-orange-500";
      case "normal": return "bg-blue-500";
      default: return "bg-gray-500";
    }
  };

  const getDiasAntesColor = (dias: number) => {
    if (dias === 3) return "text-red-500";
    if (dias === 7) return "text-orange-500";
    return "text-blue-500";
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">Operaciones Diarias</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Followups y tareas pendientes para hoy — {new Date().toLocaleDateString("es-ES", { weekday: "long", day: "numeric", month: "long" })}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant={selectedAgent === "all" ? "default" : "outline"}
            size="sm"
            onClick={() => setSelectedAgent("all")}
          >
            Todos
          </Button>
          {agents.map((agent) => (
            <Button
              key={agent}
              variant={selectedAgent === agent ? "default" : "outline"}
              size="sm"
              onClick={() => setSelectedAgent(agent)}
              className="capitalize"
            >
              <span className={`w-2 h-2 rounded-full ${getAgentColor(agent)} mr-2`} />
              {agent}
            </Button>
          ))}
        </div>
      </div>

      {/* Metrics Summary */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="pt-6">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-blue-500/10 rounded-lg">
                <Bell className="h-5 w-5 text-blue-500" />
              </div>
              <div>
                <p className="text-2xl font-semibold">{followups?.length || 0}</p>
                <p className="text-xs text-muted-foreground">Followups Hoy</p>
              </div>
            </div>
          </CardContent>
        </Card>
        
        <Card>
          <CardContent className="pt-6">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-green-500/10 rounded-lg">
                <CheckCircle className="h-5 w-5 text-green-500" />
              </div>
              <div>
                <p className="text-2xl font-semibold">{tasks?.length || 0}</p>
                <p className="text-xs text-muted-foreground">Tareas Hoy</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="pt-6">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-amber-500/10 rounded-lg">
                <AlertTriangle className="h-5 w-5 text-amber-500" />
              </div>
              <div>
                <p className="text-2xl font-semibold">
                  {followups?.filter(f => f.dias_antes === 3).length || 0}
                </p>
                <p className="text-xs text-muted-foreground">Urgentes (3 días)</p>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="pt-6">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-purple-500/10 rounded-lg">
                <TrendingUp className="h-5 w-5 text-purple-500" />
              </div>
              <div>
                <p className="text-2xl font-semibold">{tasks?.filter(t => t.prioridad === "urgente" || t.prioridad === "alta").length || 0}</p>
                <p className="text-xs text-muted-foreground">Alta Prioridad</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Followups Section */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between pb-2">
          <CardTitle className="text-lg flex items-center gap-2">
            <Calendar className="h-5 w-5" />
            Seguimientos (Followups)
          </CardTitle>
          <Badge variant="outline">{filteredFollowups?.length || 0} pendientes</Badge>
        </CardHeader>
        <CardContent>
          {followupsLoading ? (
            <p className="text-muted-foreground">Cargando...</p>
          ) : filteredFollowups?.length === 0 ? (
            <p className="text-muted-foreground text-center py-8">
              ✅ No hay followups pendientes para hoy
            </p>
          ) : (
            <div className="space-y-3">
              {filteredFollowups?.map((followup) => (
                <div
                  key={followup.id}
                  className="flex items-center justify-between p-4 border rounded-lg hover:bg-accent/50 transition-colors"
                >
                  <div className="flex items-center gap-4">
                    <div className={`w-1 h-12 rounded-full ${getDiasAntesColor(followup.dias_antes) === "text-red-500" ? "bg-red-500" : getDiasAntesColor(followup.dias_antes) === "text-orange-500" ? "bg-orange-500" : "bg-blue-500"}`} />
                    <div>
                      <p className="font-medium">{followup.nombre}</p>
                      <p className="text-sm text-muted-foreground">
                        📍 {followup.zona_preferida} • 💰 £{followup.presupuesto_max}
                      </p>
                      <div className="flex items-center gap-2 mt-1">
                        <Badge variant="outline" className="text-xs">
                          🎯 SCL: {followup.scl_score}
                        </Badge>
                        <Badge variant="outline" className="text-xs">
                          📆 {followup.fecha_mudanza}
                        </Badge>
                        <span className={`text-xs font-medium ${getDiasAntesColor(followup.dias_antes)}`}>
                          {followup.dias_antes === 3 ? "🔥 URGENTE" : followup.dias_antes === 7 ? "⏰ 7 días" : "📅 15 días"}
                        </span>
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`px-2 py-1 rounded text-xs font-medium capitalize ${getAgentColor(followup.agente_asignado)} text-white`}>
                      {followup.agente_asignado}
                    </span>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => handleMarkFollowupContacted(followup.id)}
                      disabled={markFollowup.isPending}
                    >
                      ✓ Contactado
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Tasks Section */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between pb-2">
          <CardTitle className="text-lg flex items-center gap-2">
            <CheckCircle className="h-5 w-5" />
            Tareas
          </CardTitle>
          <Badge variant="outline">{filteredTasks?.length || 0} pendientes</Badge>
        </CardHeader>
        <CardContent>
          {tasksLoading ? (
            <p className="text-muted-foreground">Cargando...</p>
          ) : filteredTasks?.length === 0 ? (
            <p className="text-muted-foreground text-center py-8">
              ✅ No hay tareas para hoy
            </p>
          ) : (
            <div className="space-y-3">
              {filteredTasks?.map((task) => (
                <div
                  key={task.id}
                  className="flex items-center justify-between p-4 border rounded-lg hover:bg-accent/50 transition-colors"
                >
                  <div className="flex items-center gap-4">
                    <div className={`w-1 h-12 rounded-full ${getPriorityColor(task.prioridad)}`} />
                    <div>
                      <p className="font-medium">{task.titulo}</p>
                      <p className="text-sm text-muted-foreground">
                        👤 {task.nombre} • 📍 {task.zona_preferida || "N/A"}
                      </p>
                      <div className="flex items-center gap-2 mt-1">
                        <Badge variant="outline" className="text-xs">
                          {task.tipo_tarea}
                        </Badge>
                        {task.hora_programada && (
                          <Badge variant="outline" className="text-xs">
                            🕐 {task.hora_programada}
                          </Badge>
                        )}
                        <span className={`text-xs font-medium px-2 py-0.5 rounded ${
                          task.prioridad === "urgente" ? "bg-red-100 text-red-700" :
                          task.prioridad === "alta" ? "bg-orange-100 text-orange-700" :
                          "bg-blue-100 text-blue-700"
                        }`}>
                          {task.prioridad}
                        </span>
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`px-2 py-1 rounded text-xs font-medium capitalize ${getAgentColor(task.agente_asignado)} text-white`}>
                      {task.agente_asignado}
                    </span>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => handleCompleteTask(task.id)}
                      disabled={completeTask.isPending}
                    >
                      ✓ Completar
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
};

export default AgentOperations;