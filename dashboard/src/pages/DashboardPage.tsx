import { Activity, CheckSquare, Newspaper, Calendar, Bot, Clock, Users, Eye, PoundSterling, TrendingUp, TrendingDown, Zap, Server, AlertTriangle, Timer, Layers, Terminal, Play, Pause, BarChart3, Radio } from "lucide-react";
import StatusDot from "@/components/StatusDot";
import { useState } from "react";

const metrics = [
  { label: "Active Tasks", value: "12", icon: CheckSquare, change: "+3 this week" },
  { label: "Content Pipeline", value: "8", icon: Newspaper, change: "3 scheduled" },
  { label: "Upcoming Events", value: "5", icon: Calendar, change: "Next 48h" },
  { label: "Agent Activity", value: "47", icon: Bot, change: "Actions today" },
];

const pipelineMetrics = [
  { label: "Leads en Pipeline", value: "159", icon: Users, change: "↑ 12%", changeType: "up" },
  { label: "Oportunidades HOT", value: "24", icon: Zap, change: "Fast Close", changeType: "hot" },
  { label: "Viewings Confirmados", value: "8", icon: Eye, change: "Next 72 hrs", changeType: "neutral" },
  { label: "CPA (Cost per Acquisition)", value: "£4.20", icon: PoundSterling, change: "↓ £0.80", changeType: "down" },
];

const activityFeed = [
  { time: "2 min ago", action: "Jeanette responded to WhatsApp lead — Flat in Canary Wharf", status: "active" as const },
  { time: "5 min ago", action: "Ivy confirmed appointment for LD-1042.", status: "active" as const },
  { time: "8 min ago", action: "New Gumtree inquiry auto-qualified — 2-bed Stratford", status: "active" as const },
  { time: "14 min ago", action: "Jeanette routed prospect (Asia) to INTL-Pool.", status: "pending" as const },
  { time: "15 min ago", action: "Content scheduled: 'London Market Tips' for Monday", status: "pending" as const },
  { time: "22 min ago", action: "Competitor listing scan completed — 14 new listings found", status: "active" as const },
  { time: "32 min ago", action: "DataSync pushed 12 records to CRM.", status: "active" as const },
  { time: "35 min ago", action: "WhatsApp Business API rate limit warning", status: "error" as const },
  { time: "1h ago", action: "Salo updated criteria for Camden zone.", status: "active" as const },
  { time: "1.5h ago", action: "Cron job: Property price update completed", status: "active" as const },
  { time: "2h ago", action: "Facebook Marketplace bot paused — awaiting config update", status: "idle" as const },
];

const leads = [
  { id: "LD-1042", name: "Sarah M.", score: 92, budget: "£1,800", routing: "Ivy (Core)", lastPing: "5 min", tier: "hot" },
  { id: "LD-1039", name: "James T.", score: 87, budget: "£2,200", routing: "Jeanette (Intl)", lastPing: "14 min", tier: "hot" },
  { id: "LD-1036", name: "Priya K.", score: 74, budget: "£1,500", routing: "Salo (Gumtree)", lastPing: "32 min", tier: "warm" },
  { id: "LD-1033", name: "Marcus L.", score: 61, budget: "£1,200", routing: "Rose (Meta)", lastPing: "1h", tier: "warm" },
  { id: "LD-1028", name: "Elena R.", score: 45, budget: "£900", routing: "Jeanette (Intl)", lastPing: "3h", tier: "cold" },
];

const aiAgents = [
  { name: "Ivy", role: "Core Agent", status: "active" as const, task: "Processing LD-1042 qualification", lastActive: "Now" },
  { name: "Salo", role: "Gumtree", status: "active" as const, task: "Scanning Camden listings", lastActive: "2 min ago" },
  { name: "Rose", role: "Meta Ads", status: "pending" as const, task: "Generating ad copy batch", lastActive: "8 min ago" },
  { name: "Jeanette", role: "International", status: "active" as const, task: "WhatsApp follow-up INTL-Pool", lastActive: "14 min ago" },
];

const killSwitches = [
  { name: "WhatsApp Ingest", channel: "WhatsApp Business API", active: true },
  { name: "Gumtree Scraper", channel: "Gumtree Pipeline", active: true },
  { name: "Facebook Marketplace", channel: "Meta API", active: false },
  { name: "Email Auto-Reply", channel: "SMTP Gateway", active: true },
];

const cronJobs = [
  { name: "Price Update Sync", schedule: "Every 6h", lastRun: "2h ago", status: "active" as const },
  { name: "Listing Scrape", schedule: "Every 4h", lastRun: "45m ago", status: "active" as const },
  { name: "Newsletter Build", schedule: "Mon 09:00", lastRun: "5d ago", status: "idle" as const },
  { name: "Analytics Report", schedule: "Daily 06:00", lastRun: "18h ago", status: "active" as const },
  { name: "CRM Data Backup", schedule: "Daily 02:00", lastRun: "22h ago", status: "active" as const },
];

const systemLogs = [
  { time: "15:42:08", level: "INFO", message: "[Ivy] Qualification pipeline processed LD-1042 → SCORE: 92" },
  { time: "15:41:55", level: "WARN", message: "[WhatsApp] Rate limit threshold at 78% — throttling enabled" },
  { time: "15:41:12", level: "INFO", message: "[Salo] Gumtree scan complete: 14 new listings indexed" },
  { time: "15:40:33", level: "INFO", message: "[DataSync] 12 records pushed to CRM successfully" },
  { time: "15:39:01", level: "ERROR", message: "[Rose] Meta API timeout on ad_set_batch_3 — retry queued" },
  { time: "15:38:22", level: "INFO", message: "[Cron] Property price update job completed in 4.2s" },
];

const DashboardPage = () => {
  const [pipelineFilter, setPipelineFilter] = useState("all");
  const [switchStates, setSwitchStates] = useState(
    killSwitches.reduce((acc, ks) => ({ ...acc, [ks.name]: ks.active }), {} as Record<string, boolean>)
  );

  const filteredLeads = pipelineFilter === "all"
    ? leads
    : leads.filter((l) => l.tier === pipelineFilter);

  const toggleSwitch = (name: string) => {
    setSwitchStates((prev) => ({ ...prev, [name]: !prev[name] }));
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">Mission Control</h1>
          <p className="text-sm text-muted-foreground mt-1">RentInLondon command center — all systems operational</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 text-xs text-muted-foreground">
            <span>API Usage:</span>
            <span className="text-primary font-medium">$14.50</span>
          </div>
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-primary/10 border border-primary/20">
            <StatusDot status="active" />
            <span className="text-xs font-medium text-primary">Ops Normal</span>
          </div>
        </div>
      </div>

      {/* Original Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {metrics.map((m) => (
          <div key={m.label} className="bg-card border border-border rounded-lg p-4 hover:border-primary/30 transition-colors">
            <div className="flex items-center justify-between mb-3">
              <m.icon className="h-4 w-4 text-muted-foreground" />
              <StatusDot status="active" />
            </div>
            <p className="text-2xl font-semibold text-foreground">{m.value}</p>
            <p className="text-xs text-muted-foreground mt-1">{m.label}</p>
            <p className="text-[10px] text-primary mt-1">{m.change}</p>
          </div>
        ))}
      </div>

      {/* CRM Pipeline Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {pipelineMetrics.map((m) => (
          <div key={m.label} className="bg-card border border-border rounded-lg p-4 hover:border-primary/30 transition-colors">
            <div className="flex items-center justify-between mb-3">
              <m.icon className="h-4 w-4 text-muted-foreground" />
              <span className={`text-[10px] font-medium ${m.changeType === "up" ? "text-primary" :
                m.changeType === "down" ? "text-status-active" :
                  m.changeType === "hot" ? "text-priority-urgent" :
                    "text-muted-foreground"
                }`}>{m.change}</span>
            </div>
            <p className="text-2xl font-semibold text-foreground">{m.value}</p>
            <p className="text-xs text-muted-foreground mt-1">{m.label}</p>
          </div>
        ))}
      </div>

      {/* Main Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Activity Feed - 2 cols */}
        <div className="lg:col-span-2 bg-card border border-border rounded-lg">
          <div className="p-4 border-b border-border flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Activity className="h-4 w-4 text-primary" />
              <h2 className="text-sm font-medium text-foreground">Live Activity Feed</h2>
            </div>
            <div className="flex items-center gap-1.5">
              <Radio className="h-3 w-3 text-status-active animate-pulse-glow" />
              <span className="text-[10px] text-muted-foreground">Real-time</span>
            </div>
          </div>
          <div className="divide-y divide-border max-h-[400px] overflow-auto">
            {activityFeed.map((item, i) => (
              <div key={i} className="px-4 py-3 flex items-start gap-3 hover:bg-accent/50 transition-colors">
                <StatusDot status={item.status} className="mt-1.5 shrink-0" />
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-foreground">{item.action}</p>
                </div>
                <div className="flex items-center gap-1 shrink-0">
                  <Clock className="h-3 w-3 text-muted-foreground" />
                  <span className="text-[10px] text-muted-foreground font-mono">{item.time}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* AI Team Status - 1 col */}
        <div className="bg-card border border-border rounded-lg">
          <div className="p-4 border-b border-border flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Bot className="h-4 w-4 text-primary" />
              <h2 className="text-sm font-medium text-foreground">AI Team Status</h2>
            </div>
          </div>
          <div className="divide-y divide-border">
            {aiAgents.map((agent) => (
              <div key={agent.name} className="p-4 hover:bg-accent/50 transition-colors">
                <div className="flex items-center justify-between mb-1">
                  <div className="flex items-center gap-2">
                    <div className="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center">
                      <span className="text-primary text-xs font-semibold">{agent.name[0]}</span>
                    </div>
                    <div>
                      <p className="text-sm font-medium text-foreground">{agent.name}</p>
                      <p className="text-[10px] text-muted-foreground">{agent.role}</p>
                    </div>
                  </div>
                  <StatusDot status={agent.status} />
                </div>
                <p className="text-xs text-muted-foreground mt-2 pl-9">{agent.task}</p>
                <p className="text-[10px] text-muted-foreground mt-1 pl-9 font-mono">{agent.lastActive}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Global Pipeline Table */}
      <div className="bg-card border border-border rounded-lg">
        <div className="p-4 border-b border-border flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Layers className="h-4 w-4 text-primary" />
            <h2 className="text-sm font-medium text-foreground">Global Pipeline</h2>
          </div>
          <div className="flex items-center gap-2">
            {["all", "hot", "warm", "cold"].map((f) => (
              <button
                key={f}
                onClick={() => setPipelineFilter(f)}
                className={`text-[10px] px-2.5 py-1 rounded-full font-medium uppercase transition-colors ${pipelineFilter === f
                  ? "bg-primary text-primary-foreground"
                  : "bg-secondary text-muted-foreground hover:text-foreground"
                  }`}
              >
                {f}
              </button>
            ))}
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-muted-foreground text-xs">
                <th className="text-left px-4 py-3 font-medium">ID/Ref</th>
                <th className="text-left px-4 py-3 font-medium">Prospect</th>
                <th className="text-left px-4 py-3 font-medium">AI Score</th>
                <th className="text-left px-4 py-3 font-medium">Budget</th>
                <th className="text-left px-4 py-3 font-medium">Routing</th>
                <th className="text-left px-4 py-3 font-medium">Last Ping</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {filteredLeads.map((lead) => (
                <tr key={lead.id} className="hover:bg-accent/50 transition-colors">
                  <td className="px-4 py-3 font-mono text-primary text-xs">{lead.id}</td>
                  <td className="px-4 py-3 text-foreground">{lead.name}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <div className="w-12 h-1.5 rounded-full bg-secondary overflow-hidden">
                        <div
                          className={`h-full rounded-full ${lead.score >= 80 ? "bg-primary" :
                            lead.score >= 60 ? "bg-status-pending" :
                              "bg-muted-foreground"
                            }`}
                          style={{ width: `${lead.score}%` }}
                        />
                      </div>
                      <span className="text-xs font-mono text-muted-foreground">{lead.score}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-foreground font-mono text-xs">{lead.budget}</td>
                  <td className="px-4 py-3 text-muted-foreground text-xs">{lead.routing}</td>
                  <td className="px-4 py-3 text-muted-foreground text-xs font-mono">{lead.lastPing}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>



      {/* Kill Switches + Cron Engine */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Kill Switches */}
        <div className="bg-card border border-border rounded-lg">
          <div className="p-4 border-b border-border">
            <div className="flex items-center gap-2">
              <AlertTriangle className="h-4 w-4 text-priority-urgent" />
              <h2 className="text-sm font-medium text-foreground">Kill Switches</h2>
            </div>
            <p className="text-[10px] text-muted-foreground mt-1">
              Pausing a node will immediately cut webhook ingestion for that channel.
            </p>
          </div>
          <div className="divide-y divide-border">
            {killSwitches.map((ks) => (
              <div key={ks.name} className="px-4 py-3 flex items-center justify-between hover:bg-accent/50 transition-colors">
                <div>
                  <p className="text-sm text-foreground">{ks.name}</p>
                  <p className="text-[10px] text-muted-foreground">{ks.channel}</p>
                </div>
                <button
                  onClick={() => toggleSwitch(ks.name)}
                  className={`relative w-10 h-5 rounded-full transition-colors ${switchStates[ks.name] ? "bg-primary" : "bg-destructive/60"
                    }`}
                >
                  <span
                    className={`absolute top-0.5 w-4 h-4 bg-foreground rounded-full transition-transform ${switchStates[ks.name] ? "left-5" : "left-0.5"
                      }`}
                  />
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* Cron Engine */}
        <div className="bg-card border border-border rounded-lg">
          <div className="p-4 border-b border-border flex items-center justify-between">
            <div>
              <div className="flex items-center gap-2">
                <Timer className="h-4 w-4 text-primary" />
                <h2 className="text-sm font-medium text-foreground">Cron Engine</h2>
              </div>
              <p className="text-[10px] text-muted-foreground mt-1">Scheduled tasks & synchronization.</p>
            </div>
          </div>
          <div className="divide-y divide-border">
            {cronJobs.map((job) => (
              <div key={job.name} className="px-4 py-3 flex items-center justify-between hover:bg-accent/50 transition-colors">
                <div className="flex items-center gap-3">
                  <StatusDot status={job.status} />
                  <div>
                    <p className="text-sm text-foreground">{job.name}</p>
                    <p className="text-[10px] text-muted-foreground font-mono">{job.schedule}</p>
                  </div>
                </div>
                <span className="text-[10px] text-muted-foreground font-mono">{job.lastRun}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* System Console */}
      <div className="bg-card border border-border rounded-lg overflow-hidden">
        <div className="p-4 border-b border-border flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Terminal className="h-4 w-4 text-primary" />
            <h2 className="text-sm font-medium text-foreground">System Console</h2>
          </div>
          <span className="text-[10px] text-muted-foreground font-mono">~/system/logs/production.log</span>
        </div>
        <div className="bg-[hsl(220_20%_5%)] p-4 font-mono text-xs space-y-1.5 max-h-[200px] overflow-auto">
          {systemLogs.map((log, i) => (
            <div key={i} className="flex gap-3">
              <span className="text-muted-foreground shrink-0">{log.time}</span>
              <span className={`shrink-0 ${log.level === "ERROR" ? "text-destructive" :
                log.level === "WARN" ? "text-status-pending" :
                  "text-primary"
                }`}>[{log.level}]</span>
              <span className="text-muted-foreground">{log.message}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default DashboardPage;
