import { useState } from "react";
import { Activity, Cpu, Zap, Clock, BarChart3, Layers, Radio, Server } from "lucide-react";
import StatusDot from "@/components/StatusDot";
import {
  BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Area, AreaChart,
} from "recharts";

/* ── Mock Data ── */
const tokensByModel = [
  { time: "00:00", "glm-5_input": 120000, "glm-5_output": 80000, "glm-4.7_input": 60000, "glm-4.7_output": 40000 },
  { time: "04:00", "glm-5_input": 180000, "glm-5_output": 95000, "glm-4.7_input": 45000, "glm-4.7_output": 30000 },
  { time: "08:00", "glm-5_input": 350000, "glm-5_output": 210000, "glm-4.7_input": 120000, "glm-4.7_output": 85000 },
  { time: "12:00", "glm-5_input": 520000, "glm-5_output": 310000, "glm-4.7_input": 180000, "glm-4.7_output": 110000 },
  { time: "16:00", "glm-5_input": 410000, "glm-5_output": 260000, "glm-4.7_input": 95000, "glm-4.7_output": 70000 },
  { time: "20:00", "glm-5_input": 280000, "glm-5_output": 190000, "glm-4.7_input": 75000, "glm-4.7_output": 55000 },
];

const tokenRateData = [
  { time: "00:00", input: 120, output: 80 },
  { time: "02:00", input: 95, output: 65 },
  { time: "04:00", input: 180, output: 140 },
  { time: "06:00", input: 220, output: 170 },
  { time: "08:00", input: 380, output: 290 },
  { time: "10:00", input: 450, output: 350 },
  { time: "12:00", input: 520, output: 410 },
  { time: "14:00", input: 390, output: 300 },
  { time: "16:00", input: 340, output: 250 },
  { time: "18:00", input: 280, output: 210 },
  { time: "20:00", input: 200, output: 150 },
  { time: "22:00", input: 150, output: 110 },
];

const totalTokensPie = [
  { name: "glm-5", value: 12180000, color: "hsl(199, 89%, 48%)" },
  { name: "glm-4.7", value: 6150000, color: "hsl(142, 71%, 45%)" },
];

const messageQueuedRate = [
  { time: "00:00", telegram: 12, whatsapp: 45, gumtree: 8 },
  { time: "04:00", telegram: 8, whatsapp: 32, gumtree: 15 },
  { time: "08:00", telegram: 25, whatsapp: 89, gumtree: 42 },
  { time: "12:00", telegram: 35, whatsapp: 120, gumtree: 55 },
  { time: "16:00", telegram: 28, whatsapp: 95, gumtree: 38 },
  { time: "20:00", telegram: 15, whatsapp: 60, gumtree: 20 },
];

const messagesByOutcome = [
  { time: "00:00", success: 50, failed: 2, timeout: 1 },
  { time: "04:00", success: 38, failed: 1, timeout: 0 },
  { time: "08:00", success: 130, failed: 5, timeout: 3 },
  { time: "12:00", success: 180, failed: 8, timeout: 2 },
  { time: "16:00", success: 140, failed: 3, timeout: 1 },
  { time: "20:00", success: 85, failed: 2, timeout: 1 },
];

const latencyData = [
  { time: "00:00", p50: 120, p90: 350, p99: 800 },
  { time: "04:00", p50: 95, p90: 280, p99: 650 },
  { time: "08:00", p50: 180, p90: 520, p99: 1200 },
  { time: "12:00", p50: 210, p90: 600, p99: 1400 },
  { time: "16:00", p50: 160, p90: 450, p99: 1050 },
  { time: "20:00", p50: 130, p90: 380, p99: 900 },
];

const queueDepth = [
  { time: "00:00", priority: 2, standard: 8, bulk: 15 },
  { time: "04:00", priority: 1, standard: 5, bulk: 12 },
  { time: "08:00", priority: 5, standard: 18, bulk: 35 },
  { time: "12:00", priority: 8, standard: 25, bulk: 42 },
  { time: "16:00", priority: 4, standard: 15, bulk: 28 },
  { time: "20:00", priority: 2, standard: 10, bulk: 18 },
];

const sessionStateData = [
  { time: "00:00", active: 12, idle: 35, stuck: 1 },
  { time: "04:00", active: 8, idle: 40, stuck: 0 },
  { time: "08:00", active: 28, idle: 22, stuck: 2 },
  { time: "12:00", active: 35, idle: 15, stuck: 3 },
  { time: "16:00", active: 25, idle: 20, stuck: 1 },
  { time: "20:00", active: 15, idle: 30, stuck: 0 },
];

const agentMetrics = [
  { name: "Alex", model: "Claude 3.5 Sonnet", tokens: "142K", latency: "0.8s", msgs: 312, status: "active" as const },
  { name: "Ivy", model: "Claude 3.5 Sonnet", tokens: "289K", latency: "1.1s", msgs: 547, status: "active" as const },
  { name: "Salo", model: "Claude 3.5 Haiku", tokens: "198K", latency: "0.6s", msgs: 423, status: "active" as const },
  { name: "Rose", model: "Claude 3.5 Sonnet", tokens: "95K", latency: "1.3s", msgs: 189, status: "active" as const },
  { name: "Jeanette", model: "GPT-4o", tokens: "0", latency: "—", msgs: 0, status: "error" as const },
];

const telemetryStats = [
  { label: "Tokens Consumed", value: "1.2M", sub: "Current billing cycle" },
  { label: "Messages Processed", value: "3,847", sub: "In/Out combined" },
  { label: "Avg Latency", value: "0.8s", sub: "API LLM response" },
  { label: "Queue Backlog", value: "3", sub: "Events waiting" },
];

const chartTooltipStyle = {
  contentStyle: { background: 'hsl(220, 18%, 10%)', border: '1px solid hsl(220, 14%, 16%)', borderRadius: '8px', fontSize: '12px' },
  labelStyle: { color: 'hsl(210, 20%, 92%)' },
};

const SectionHeader = ({ title, subtitle }: { title: string; subtitle?: string }) => (
  <div className="col-span-full border-b border-border pb-2 mb-2">
    <h2 className="text-sm font-semibold text-foreground uppercase tracking-wider">{title}</h2>
    {subtitle && <p className="text-xs text-muted-foreground">{subtitle}</p>}
  </div>
);

const TelemetryPage = () => {
  const [timeRange, setTimeRange] = useState<'7d' | '30d'>('7d');

  const totalTokens = totalTokensPie.reduce((s, t) => s + t.value, 0);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">OpenClaw Telemetry</h1>
          <p className="text-sm text-muted-foreground mt-1">Métricas de red, tokens y salud del motor IA en tiempo real</p>
        </div>
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1 bg-card border border-border rounded-lg p-0.5">
            {(['7d', '30d'] as const).map(r => (
              <button
                key={r}
                onClick={() => setTimeRange(r)}
                className={`px-3 py-1 text-xs rounded-md transition-colors ${timeRange === r ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:text-foreground'
                  }`}
              >
                {r === '7d' ? '7 Días' : '30 Días'}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-border bg-card">
            <StatusDot status="active" />
            <span className="text-xs text-foreground">Ops Normal</span>
          </div>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[
          { label: "Total Tokens", value: `${(totalTokens / 1e6).toFixed(2)} Mil`, icon: Zap, sub: "Ciclo actual" },
          { label: "Mensajes Procesados", value: "3,847", icon: Activity, sub: "In/Out combinados" },
          { label: "Latencia Promedio", value: "1.2s", icon: Clock, sub: "Respuesta API LLM" },
          { label: "Backlog de Cola", value: "12", icon: Layers, sub: "Eventos en espera" },
        ].map(kpi => (
          <div key={kpi.label} className="bg-card border border-border rounded-lg p-4">
            <div className="flex items-center gap-2 mb-2">
              <kpi.icon className="h-4 w-4 text-primary" />
              <span className="text-xs text-muted-foreground">{kpi.label}</span>
            </div>
            <p className="text-xl font-bold text-foreground font-mono">{kpi.value}</p>
            <p className="text-[10px] text-muted-foreground mt-1">{kpi.sub}</p>
          </div>
        ))}
      </div>

      {/* AI Telemetry (Moved from Dashboard) */}
      <div className="bg-card border border-border rounded-lg">
        <div className="p-4 border-b border-border flex items-center justify-between">
          <div>
            <div className="flex items-center gap-2">
              <BarChart3 className="h-4 w-4 text-primary" />
              <h2 className="text-sm font-medium text-foreground">AI Telemetry</h2>
            </div>
            <p className="text-xs text-muted-foreground mt-1">Real-time model metrics and token consumption.</p>
          </div>
        </div>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 p-4">
          {telemetryStats.map((stat) => (
            <div key={stat.label} className="bg-secondary/50 rounded-lg p-4">
              <p className="text-xs text-muted-foreground">{stat.label}</p>
              <p className="text-xl font-semibold text-foreground mt-1">{stat.value}</p>
              <p className="text-[10px] text-muted-foreground mt-1">{stat.sub}</p>
            </div>
          ))}
        </div>
        <div className="px-4 pb-4">
          <div className="bg-secondary/30 rounded-lg p-4 border border-border">
            <div className="flex items-center gap-2 mb-2">
              <Zap className="h-3.5 w-3.5 text-primary" />
              <span className="text-xs font-medium text-foreground">Operational Insight</span>
            </div>
            <p className="text-xs text-muted-foreground leading-relaxed">
              Salo (Haiku Model) is handling 68% of transactional volume while maintaining latency &lt; 1s.
              Recommended to keep current routing to optimize API costs.
            </p>
          </div>
        </div>
      </div>

      {/* ── Agent Telemetry Table ── */}
      <div className="bg-card border border-border rounded-lg p-4">
        <h3 className="text-sm font-medium text-foreground mb-4">Telemetría por Agente</h3>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border">
                <th className="text-left py-2 px-3 text-xs font-semibold text-muted-foreground uppercase">Agente</th>
                <th className="text-left py-2 px-3 text-xs font-semibold text-muted-foreground uppercase">Modelo</th>
                <th className="text-right py-2 px-3 text-xs font-semibold text-muted-foreground uppercase">Tokens</th>
                <th className="text-right py-2 px-3 text-xs font-semibold text-muted-foreground uppercase">Latencia</th>
                <th className="text-right py-2 px-3 text-xs font-semibold text-muted-foreground uppercase">Mensajes</th>
                <th className="text-center py-2 px-3 text-xs font-semibold text-muted-foreground uppercase">Estado</th>
              </tr>
            </thead>
            <tbody>
              {agentMetrics.map(a => (
                <tr key={a.name} className="border-b border-border/50 hover:bg-accent/30 transition-colors">
                  <td className="py-2.5 px-3 font-medium text-foreground">{a.name}</td>
                  <td className="py-2.5 px-3 text-muted-foreground font-mono text-xs">{a.model}</td>
                  <td className="py-2.5 px-3 text-right font-mono text-foreground">{a.tokens}</td>
                  <td className="py-2.5 px-3 text-right font-mono text-foreground">{a.latency}</td>
                  <td className="py-2.5 px-3 text-right font-mono text-foreground">{a.msgs}</td>
                  <td className="py-2.5 px-3 text-center"><StatusDot status={a.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Token Usage Section ── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <SectionHeader title="Token Usage" />

        {/* Total Tokens Pie */}
        <div className="bg-card border border-border rounded-lg p-4">
          <h3 className="text-sm font-medium text-foreground mb-4">Total Tokens Used by Models</h3>
          <ResponsiveContainer width="100%" height={280}>
            <PieChart>
              <Pie data={totalTokensPie} cx="50%" cy="50%" innerRadius={70} outerRadius={100} dataKey="value" strokeWidth={0}>
                {totalTokensPie.map((entry, i) => <Cell key={i} fill={entry.color} />)}
              </Pie>
              <Tooltip {...chartTooltipStyle} formatter={(v: number) => `${(v / 1e6).toFixed(2)} Mil`} />
              <Legend />
            </PieChart>
          </ResponsiveContainer>
          <div className="text-center -mt-[170px] mb-[120px]">
            <p className="text-2xl font-bold text-foreground font-mono">{(totalTokens / 1e6).toFixed(2)}<span className="text-sm ml-1">Mil</span></p>
          </div>
        </div>

        {/* Token Type Breakdown Bar */}
        <div className="bg-card border border-border rounded-lg p-4">
          <h3 className="text-sm font-medium text-foreground mb-4">Token Type Breakdown By Model</h3>
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={tokensByModel}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(220, 14%, 16%)" />
              <XAxis dataKey="time" tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <YAxis tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} tickFormatter={v => `${(v / 1000).toFixed(0)}K`} />
              <Tooltip {...chartTooltipStyle} />
              <Legend wrapperStyle={{ fontSize: '10px' }} />
              <Bar dataKey="glm-5_input" name="prompt - glm-5" fill="hsl(199, 89%, 48%)" radius={[2, 2, 0, 0]} />
              <Bar dataKey="glm-5_output" name="output - glm-5" fill="hsl(199, 89%, 68%)" radius={[2, 2, 0, 0]} />
              <Bar dataKey="glm-4.7_input" name="input - glm-4.7" fill="hsl(142, 71%, 45%)" radius={[2, 2, 0, 0]} />
              <Bar dataKey="glm-4.7_output" name="output - glm-4.7" fill="hsl(142, 71%, 65%)" radius={[2, 2, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Token Usage by Models (bar) */}
        <div className="bg-card border border-border rounded-lg p-4">
          <h3 className="text-sm font-medium text-foreground mb-4">Token Usage by Models</h3>
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={tokensByModel}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(220, 14%, 16%)" />
              <XAxis dataKey="time" tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <YAxis tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} tickFormatter={v => `${(v / 1000).toFixed(0)}K`} />
              <Tooltip {...chartTooltipStyle} />
              <Legend wrapperStyle={{ fontSize: '10px' }} />
              <Bar dataKey="glm-5_input" name="glm-5 (input)" stackId="a" fill="hsl(199, 89%, 48%)" />
              <Bar dataKey="glm-4.7_input" name="glm-4.7 (input)" stackId="b" fill="hsl(25, 95%, 53%)" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Input vs Output Token Rate */}
        <div className="bg-card border border-border rounded-lg p-4">
          <h3 className="text-sm font-medium text-foreground mb-4">Input vs Output Token Rate</h3>
          <ResponsiveContainer width="100%" height={280}>
            <LineChart data={tokenRateData}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(220, 14%, 16%)" />
              <XAxis dataKey="time" tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <YAxis tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <Tooltip {...chartTooltipStyle} />
              <Legend wrapperStyle={{ fontSize: '10px' }} />
              <Line type="monotone" dataKey="output" name="Output Tokens/s" stroke="hsl(199, 89%, 48%)" strokeWidth={2} dot={false} />
              <Line type="monotone" dataKey="input" name="Input Tokens/s" stroke="hsl(25, 95%, 53%)" strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* ── Message Flow Section ── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <SectionHeader title="Message Flow (All channels)" />

        <div className="bg-card border border-border rounded-lg p-4">
          <h3 className="text-sm font-medium text-foreground mb-4">Message Queued Rate</h3>
          <ResponsiveContainer width="100%" height={280}>
            <AreaChart data={messageQueuedRate}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(220, 14%, 16%)" />
              <XAxis dataKey="time" tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <YAxis tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <Tooltip {...chartTooltipStyle} />
              <Legend wrapperStyle={{ fontSize: '10px' }} />
              <Area type="monotone" dataKey="whatsapp" name="WhatsApp" stroke="hsl(142, 71%, 45%)" fill="hsl(142, 71%, 45%)" fillOpacity={0.15} />
              <Area type="monotone" dataKey="telegram" name="Telegram" stroke="hsl(199, 89%, 48%)" fill="hsl(199, 89%, 48%)" fillOpacity={0.15} />
              <Area type="monotone" dataKey="gumtree" name="Gumtree" stroke="hsl(270, 60%, 60%)" fill="hsl(270, 60%, 60%)" fillOpacity={0.15} />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="bg-card border border-border rounded-lg p-4">
          <h3 className="text-sm font-medium text-foreground mb-4">Messages Processed by Outcome</h3>
          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={messagesByOutcome}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(220, 14%, 16%)" />
              <XAxis dataKey="time" tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <YAxis tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <Tooltip {...chartTooltipStyle} />
              <Legend wrapperStyle={{ fontSize: '10px' }} />
              <Bar dataKey="success" name="Success" fill="hsl(142, 71%, 45%)" radius={[2, 2, 0, 0]} />
              <Bar dataKey="failed" name="Failed" fill="hsl(0, 84%, 60%)" radius={[2, 2, 0, 0]} />
              <Bar dataKey="timeout" name="Timeout" fill="hsl(43, 96%, 56%)" radius={[2, 2, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="bg-card border border-border rounded-lg p-4">
          <h3 className="text-sm font-medium text-foreground mb-4">Message Processing Latency (p50, p90, p99)</h3>
          <ResponsiveContainer width="100%" height={280}>
            <LineChart data={latencyData}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(220, 14%, 16%)" />
              <XAxis dataKey="time" tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <YAxis tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} unit="ms" />
              <Tooltip {...chartTooltipStyle} />
              <Legend wrapperStyle={{ fontSize: '10px' }} />
              <Line type="monotone" dataKey="p50" stroke="hsl(199, 89%, 48%)" strokeWidth={2} dot={false} />
              <Line type="monotone" dataKey="p90" stroke="hsl(43, 96%, 56%)" strokeWidth={2} dot={false} />
              <Line type="monotone" dataKey="p99" stroke="hsl(0, 84%, 60%)" strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Placeholder for 4th chart */}
        <div className="bg-card border border-border rounded-lg p-4">
          <h3 className="text-sm font-medium text-foreground mb-4">Message Error Rate</h3>
          <ResponsiveContainer width="100%" height={280}>
            <AreaChart data={messagesByOutcome}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(220, 14%, 16%)" />
              <XAxis dataKey="time" tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <YAxis tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <Tooltip {...chartTooltipStyle} />
              <Legend wrapperStyle={{ fontSize: '10px' }} />
              <Area type="monotone" dataKey="failed" name="Errores" stroke="hsl(0, 84%, 60%)" fill="hsl(0, 84%, 60%)" fillOpacity={0.2} />
              <Area type="monotone" dataKey="timeout" name="Timeouts" stroke="hsl(43, 96%, 56%)" fill="hsl(43, 96%, 56%)" fillOpacity={0.2} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* ── Queue & Session Health ── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <SectionHeader title="Queue & Session Health" />

        <div className="bg-card border border-border rounded-lg p-4">
          <h3 className="text-sm font-medium text-foreground mb-4">Queue Depth by Lane</h3>
          <ResponsiveContainer width="100%" height={280}>
            <AreaChart data={queueDepth}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(220, 14%, 16%)" />
              <XAxis dataKey="time" tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <YAxis tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <Tooltip {...chartTooltipStyle} />
              <Legend wrapperStyle={{ fontSize: '10px' }} />
              <Area type="monotone" dataKey="priority" name="Priority" stroke="hsl(0, 84%, 60%)" fill="hsl(0, 84%, 60%)" fillOpacity={0.15} stackId="1" />
              <Area type="monotone" dataKey="standard" name="Standard" stroke="hsl(199, 89%, 48%)" fill="hsl(199, 89%, 48%)" fillOpacity={0.15} stackId="1" />
              <Area type="monotone" dataKey="bulk" name="Bulk" stroke="hsl(220, 10%, 50%)" fill="hsl(220, 10%, 50%)" fillOpacity={0.15} stackId="1" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="bg-card border border-border rounded-lg p-4">
          <h3 className="text-sm font-medium text-foreground mb-4">Session State Transitions</h3>
          <ResponsiveContainer width="100%" height={280}>
            <LineChart data={sessionStateData}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(220, 14%, 16%)" />
              <XAxis dataKey="time" tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <YAxis tick={{ fontSize: 10, fill: 'hsl(215, 15%, 55%)' }} />
              <Tooltip {...chartTooltipStyle} />
              <Legend wrapperStyle={{ fontSize: '10px' }} />
              <Line type="monotone" dataKey="active" name="Active" stroke="hsl(142, 71%, 45%)" strokeWidth={2} dot={false} />
              <Line type="monotone" dataKey="idle" name="Idle" stroke="hsl(220, 10%, 50%)" strokeWidth={2} dot={false} />
              <Line type="monotone" dataKey="stuck" name="Stuck" stroke="hsl(0, 84%, 60%)" strokeWidth={2} dot={false} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>


    </div>
  );
};

export default TelemetryPage;
