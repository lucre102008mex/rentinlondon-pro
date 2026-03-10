import { useState } from "react";
import { AlertTriangle, Bot, MessageSquare, DollarSign, Wifi } from "lucide-react";
import StatusDot from "@/components/StatusDot";

interface AgentNode {
  name: string;
  role: string;
  channel: string;
  channelType: string;
  status: 'active' | 'pending' | 'error' | 'idle';
  statusLabel: string;
  model: string;
  tokensToday: string;
  latency: string;
  messagesProcessed: number;
  killSwitchActive: boolean;
}

const initialAgents: AgentNode[] = [
  { name: "Alex", role: "Admin / Sistema", channel: "Telegram", channelType: "Telegram", status: "active", statusLabel: "Online / Procesando", model: "Claude 3.5 Sonnet", tokensToday: "142K", latency: "0.8s", messagesProcessed: 312, killSwitchActive: false },
  { name: "Ivy", role: "Captación General", channel: "WhatsApp", channelType: "(Business UK)", status: "active", statusLabel: "Online / Procesando", model: "Claude 3.5 Sonnet", tokensToday: "289K", latency: "1.1s", messagesProcessed: 547, killSwitchActive: false },
  { name: "Salo", role: "Gumtree & Listings", channel: "WhatsApp", channelType: "(Gumtree)", status: "active", statusLabel: "Online / Procesando", model: "Claude 3.5 Haiku", tokensToday: "198K", latency: "0.6s", messagesProcessed: 423, killSwitchActive: false },
  { name: "Rose", role: "Ads Performance", channel: "WhatsApp", channelType: "(Ads)", status: "active", statusLabel: "Online / Procesando", model: "Claude 3.5 Sonnet", tokensToday: "95K", latency: "1.3s", messagesProcessed: 189, killSwitchActive: false },
  { name: "Jeanette", role: "Internacional / Visas", channel: "WhatsApp", channelType: "(Handoff)", status: "error", statusLabel: "Pausado (Kill-Switch)", model: "GPT-4o", tokensToday: "0", latency: "—", messagesProcessed: 0, killSwitchActive: true },
];

const AgentControlPage = () => {
  const [agents, setAgents] = useState(initialAgents);

  const toggleKillSwitch = (index: number) => {
    setAgents(prev => prev.map((a, i) => {
      if (i !== index) return a;
      const newKill = !a.killSwitchActive;
      return {
        ...a,
        killSwitchActive: newKill,
        status: newKill ? 'error' as const : 'active' as const,
        statusLabel: newKill ? 'Pausado (Kill-Switch)' : 'Online / Procesando',
      };
    }));
  };

  const apiCostToday = "$14.50";
  const activeCount = agents.filter(a => !a.killSwitchActive).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">Control de Agentes</h1>
          <p className="text-sm text-muted-foreground mt-1">Panel de control y kill-switches para nodos IA</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-border bg-card">
            <DollarSign className="h-3.5 w-3.5 text-muted-foreground" />
            <span className="text-xs text-muted-foreground">API Hoy:</span>
            <span className="text-sm font-semibold text-foreground">{apiCostToday}</span>
          </div>
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-border bg-card">
            <StatusDot status="active" />
            <span className="text-xs text-foreground">Conexión Firestore OK</span>
          </div>
        </div>
      </div>

      {/* Kill-Switch Warning */}
      <div className="rounded-lg border border-priority-high/30 bg-priority-high/5 p-4 flex items-start gap-3">
        <AlertTriangle className="h-5 w-5 text-priority-high shrink-0 mt-0.5" />
        <div>
          <p className="text-sm font-medium text-foreground">
            <span className="font-semibold">Kill-Switches Activos:</span> Pausar a un agente cortará inmediatamente su capacidad de enviar mensajes vía WhatsApp/Telegram. Utilizar solo en caso de alucinaciones o errores severos.
          </p>
        </div>
      </div>

      {/* Agent Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {agents.map((agent, index) => (
          <div
            key={agent.name}
            className={`bg-card border rounded-xl p-5 transition-all ${
              agent.killSwitchActive
                ? 'border-destructive/30 bg-destructive/5'
                : 'border-border hover:border-primary/30'
            }`}
          >
            {/* Agent Header */}
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-secondary flex items-center justify-center">
                  <Bot className="h-5 w-5 text-muted-foreground" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-base font-semibold text-foreground">{agent.name}</h3>
                    <StatusDot status={agent.status} />
                  </div>
                  <p className="text-xs text-muted-foreground">{agent.role}</p>
                </div>
              </div>
            </div>

            {/* Agent Details */}
            <div className="space-y-2.5 mb-4">
              <div className="flex items-center justify-between">
                <span className="text-xs text-muted-foreground">Canal Asignado:</span>
                <span className="text-xs font-medium text-foreground">{agent.channel} {agent.channelType}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-xs text-muted-foreground">Modelo:</span>
                <span className="text-xs font-medium text-foreground font-mono">{agent.model}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-xs text-muted-foreground">Tokens Hoy:</span>
                <span className="text-xs font-medium text-foreground font-mono">{agent.tokensToday}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-xs text-muted-foreground">Latencia:</span>
                <span className="text-xs font-medium text-foreground font-mono">{agent.latency}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-xs text-muted-foreground">Msgs Procesados:</span>
                <span className="text-xs font-medium text-foreground font-mono">{agent.messagesProcessed}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-xs text-muted-foreground">Estado Actual:</span>
                <span className={`text-xs font-medium ${
                  agent.killSwitchActive ? 'text-destructive' : 'text-status-active'
                }`}>
                  • {agent.statusLabel}
                </span>
              </div>
            </div>

            {/* Kill Switch */}
            <button
              onClick={() => toggleKillSwitch(index)}
              className={`w-full py-2 rounded-lg text-xs font-medium transition-all ${
                agent.killSwitchActive
                  ? 'bg-status-active/10 text-status-active border border-status-active/30 hover:bg-status-active/20'
                  : 'bg-destructive/10 text-destructive border border-destructive/30 hover:bg-destructive/20'
              }`}
            >
              {agent.killSwitchActive ? '▶ Reactivar Agente' : '⏸ Activar Kill-Switch'}
            </button>
          </div>
        ))}
      </div>

      {/* Summary Bar */}
      <div className="bg-card border border-border rounded-lg p-4 flex items-center justify-between">
        <div className="flex items-center gap-6">
          <div className="flex items-center gap-2">
            <Wifi className="h-4 w-4 text-status-active" />
            <span className="text-sm text-foreground">{activeCount}/{agents.length} Nodos Activos</span>
          </div>
          <div className="flex items-center gap-2">
            <MessageSquare className="h-4 w-4 text-primary" />
            <span className="text-sm text-muted-foreground">
              Total Msgs: {agents.reduce((s, a) => s + a.messagesProcessed, 0).toLocaleString()}
            </span>
          </div>
        </div>
        <span className="text-xs text-muted-foreground">Última sincronización: hace 30s</span>
      </div>
    </div>
  );
};

export default AgentControlPage;
