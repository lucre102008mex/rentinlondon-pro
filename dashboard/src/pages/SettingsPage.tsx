import StatusDot from "@/components/StatusDot";
import { Settings2, Plug, Bot, Clock } from "lucide-react";

const integrations = [
  { name: 'WhatsApp Business API', status: 'active' as const, lastSync: '2 min ago' },
  { name: 'Facebook Marketplace', status: 'idle' as const, lastSync: 'Paused' },
  { name: 'Gumtree', status: 'active' as const, lastSync: '5 min ago' },
  { name: 'BeehIiv', status: 'active' as const, lastSync: '1h ago' },
  { name: 'AWS EC2', status: 'active' as const, lastSync: '3 min ago' },
  { name: 'Google Cloud', status: 'active' as const, lastSync: '10 min ago' },
  { name: 'Notion', status: 'pending' as const, lastSync: 'Syncing...' },
];

const cronJobs = [
  { name: 'Property price update', schedule: 'Every 6 hours', status: 'active' as const, lastRun: '2h ago' },
  { name: 'Competitor listing scan', schedule: 'Daily at 06:00', status: 'active' as const, lastRun: '18h ago' },
  { name: 'WhatsApp bot health check', schedule: 'Every 30 min', status: 'active' as const, lastRun: '12 min ago' },
  { name: 'Newsletter subscriber sync', schedule: 'Daily at 09:00', status: 'active' as const, lastRun: '23h ago' },
  { name: 'Lead follow-up batch', schedule: 'Every 4 hours', status: 'active' as const, lastRun: '1h ago' },
  { name: 'Analytics report', schedule: 'Weekly Mon 08:00', status: 'pending' as const, lastRun: '5 days ago' },
];

const agentConfig = {
  model: 'GPT-4 Turbo',
  temperature: '0.3',
  maxTokens: '4096',
  escalationRules: [
    'Unrecognized intent after 2 attempts',
    'Payment or financial discussions',
    'Complaints or negative sentiment',
    'Maintenance requests over £500',
    'Legal or contract questions',
  ],
};

const SettingsPage = () => {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-semibold text-foreground">Settings</h1>
        <p className="text-sm text-muted-foreground mt-1">System configuration and integrations</p>
      </div>

      {/* Cron Jobs */}
      <div>
        <div className="flex items-center gap-2 mb-4">
          <Clock className="h-4 w-4 text-primary" />
          <h2 className="text-sm font-semibold text-foreground">Cron Jobs</h2>
        </div>
        <div className="bg-card border border-border rounded-lg divide-y divide-border">
          {cronJobs.map(job => (
            <div key={job.name} className="px-4 py-3 flex items-center gap-4">
              <StatusDot status={job.status} />
              <div className="flex-1">
                <p className="text-sm text-foreground">{job.name}</p>
                <p className="text-[10px] text-muted-foreground font-mono">{job.schedule}</p>
              </div>
              <span className="text-[10px] text-muted-foreground">Last: {job.lastRun}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Integrations */}
      <div>
        <div className="flex items-center gap-2 mb-4">
          <Plug className="h-4 w-4 text-primary" />
          <h2 className="text-sm font-semibold text-foreground">Integrations</h2>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {integrations.map(int => (
            <div key={int.name} className="bg-card border border-border rounded-lg p-4 flex items-center gap-3">
              <StatusDot status={int.status} />
              <div>
                <p className="text-sm font-medium text-foreground">{int.name}</p>
                <p className="text-[10px] text-muted-foreground">{int.lastSync}</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Agent Config */}
      <div>
        <div className="flex items-center gap-2 mb-4">
          <Bot className="h-4 w-4 text-primary" />
          <h2 className="text-sm font-semibold text-foreground">Jeanette — Agent Configuration</h2>
        </div>
        <div className="bg-card border border-border rounded-lg p-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
            <div>
              <p className="text-[10px] text-muted-foreground uppercase mb-1">Model</p>
              <p className="text-sm font-medium text-foreground font-mono">{agentConfig.model}</p>
            </div>
            <div>
              <p className="text-[10px] text-muted-foreground uppercase mb-1">Temperature</p>
              <p className="text-sm font-medium text-foreground font-mono">{agentConfig.temperature}</p>
            </div>
            <div>
              <p className="text-[10px] text-muted-foreground uppercase mb-1">Max Tokens</p>
              <p className="text-sm font-medium text-foreground font-mono">{agentConfig.maxTokens}</p>
            </div>
          </div>
          <div>
            <p className="text-[10px] text-muted-foreground uppercase mb-2">Escalation Rules</p>
            <ul className="space-y-1">
              {agentConfig.escalationRules.map((rule, i) => (
                <li key={i} className="text-sm text-foreground/80 flex items-center gap-2">
                  <span className="w-1.5 h-1.5 rounded-full bg-priority-high shrink-0" />
                  {rule}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SettingsPage;
