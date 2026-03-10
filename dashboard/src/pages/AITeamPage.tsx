import { useState } from "react";
import { Bot, X, BarChart3, Clock, ChevronRight } from "lucide-react";
import StatusDot from "@/components/StatusDot";

interface Agent {
  name: string;
  role: string;
  currentTask: string;
  status: 'active' | 'pending' | 'error' | 'idle';
  lastActive: string;
  responsibilities: string[];
  recentWork: string[];
  performance: { label: string; value: string }[];
}

interface AgentGroup {
  label: string;
  agents: Agent[];
}

const jeanette: Agent = {
  name: 'Jeanette',
  role: 'Lead AI Agent — Tenant Qualification, Lead Response & WhatsApp Automation for RentInLondon',
  currentTask: 'Processing 3 WhatsApp leads from Gumtree campaign',
  status: 'active',
  lastActive: 'Now',
  responsibilities: ['Lead qualification & tenant screening', 'WhatsApp Business auto-responses', 'Gumtree & Facebook lead handling', 'Coordinating sub-agents'],
  recentWork: ['Qualified 15 leads in last 24h', 'Updated WhatsApp response templates', 'Escalated 2 complex inquiries'],
  performance: [{ label: 'Leads Qualified', value: '47' }, { label: 'Response Time', value: '< 2min' }, { label: 'Accuracy', value: '94%' }],
};

const subGroups: AgentGroup[] = [
  {
    label: 'Operators',
    agents: [
      { name: 'WhatsApp Responder', role: 'Auto-responds to WhatsApp inquiries', currentTask: 'Handling 2 active conversations', status: 'active', lastActive: '1 min ago', responsibilities: ['Instant lead responses', 'Qualification questions', 'Viewing scheduling'], recentWork: ['Responded to 23 messages today', 'Scheduled 3 viewings'], performance: [{ label: 'Messages', value: '23' }, { label: 'Avg Response', value: '45s' }] },
      { name: 'Gumtree Handler', role: 'Processes Gumtree listing inquiries', currentTask: 'Monitoring new inquiries', status: 'active', lastActive: '5 min ago', responsibilities: ['Inquiry monitoring', 'Auto-qualification', 'Follow-up sequences'], recentWork: ['Processed 8 new inquiries', 'Updated listing responses'], performance: [{ label: 'Inquiries', value: '8' }, { label: 'Qualified', value: '5' }] },
      { name: 'FB Marketplace Bot', role: 'Facebook Marketplace automation', currentTask: 'Paused — awaiting config update', status: 'idle', lastActive: '2h ago', responsibilities: ['Auto-responses', 'Lead capture', 'Listing management'], recentWork: ['Last active 2 hours ago', 'Config update pending'], performance: [{ label: 'Status', value: 'Paused' }] },
    ],
  },
  {
    label: 'Researchers',
    agents: [
      { name: 'Market Pricing Scraper', role: 'Monitors rental market pricing', currentTask: 'Running Zone 2 price comparison', status: 'active', lastActive: '10 min ago', responsibilities: ['Price monitoring', 'Market trend analysis', 'Competitor tracking'], recentWork: ['Completed Zone 1-3 scan', 'Found 14 pricing updates'], performance: [{ label: 'Scans Today', value: '3' }, { label: 'Data Points', value: '142' }] },
      { name: 'Listing Monitor', role: 'Tracks competitor listings', currentTask: 'Scanning new Rightmove listings', status: 'active', lastActive: '15 min ago', responsibilities: ['New listing alerts', 'Competitor analysis', 'Market gap identification'], recentWork: ['Flagged 6 competitive listings', 'Updated pricing recommendations'], performance: [{ label: 'Listings Tracked', value: '89' }] },
    ],
  },
  {
    label: 'Writers',
    agents: [
      { name: 'Listing Copy Generator', role: 'Creates property listing descriptions', currentTask: 'Drafting copy for Stratford 2-bed', status: 'pending', lastActive: '20 min ago', responsibilities: ['SEO-optimized descriptions', 'Platform-specific formatting', 'Photo caption generation'], recentWork: ['Generated 3 listing descriptions', 'Updated template library'], performance: [{ label: 'Listings Written', value: '12' }] },
      { name: 'Newsletter Drafter', role: 'Creates BeehIiv newsletter content', currentTask: 'Drafting weekly market update', status: 'pending', lastActive: '1h ago', responsibilities: ['Weekly newsletters', 'Subscriber engagement', 'Market insights'], recentWork: ['Drafted weekly update', 'A/B tested subject lines'], performance: [{ label: 'Open Rate', value: '42%' }] },
      { name: 'Social Caption Writer', role: 'Writes social media captions', currentTask: 'Idle — awaiting next batch', status: 'idle', lastActive: '3h ago', responsibilities: ['Platform-optimized captions', 'Hashtag research', 'CTA optimization'], recentWork: ['Wrote 5 Instagram captions', 'Updated hashtag library'], performance: [{ label: 'Posts', value: '5' }] },
    ],
  },
  {
    label: 'Developers',
    agents: [
      { name: 'Webhook Manager', role: 'Manages webhook integrations', currentTask: 'Monitoring webhook health', status: 'active', lastActive: '2 min ago', responsibilities: ['Webhook routing', 'Error handling', 'Integration monitoring'], recentWork: ['Processed 156 webhooks today', '0 failures'], performance: [{ label: 'Uptime', value: '99.9%' }, { label: 'Processed', value: '156' }] },
      { name: 'API Monitor', role: 'API integration health checks', currentTask: 'Running scheduled health checks', status: 'active', lastActive: '5 min ago', responsibilities: ['API health monitoring', 'Rate limit management', 'Error alerting'], recentWork: ['All APIs healthy', 'Gumtree rate limit at 60%'], performance: [{ label: 'APIs', value: '7/7 ✓' }] },
      { name: 'Cron Overseer', role: 'Manages scheduled tasks', currentTask: 'Next job in 12 minutes', status: 'active', lastActive: '3 min ago', responsibilities: ['Job scheduling', 'Execution monitoring', 'Failure recovery'], recentWork: ['Ran 24 jobs today', '1 retry needed'], performance: [{ label: 'Jobs Today', value: '24' }, { label: 'Success', value: '96%' }] },
    ],
  },
];

const AITeamPage = () => {
  const [selected, setSelected] = useState<Agent | null>(null);

  const AgentCard = ({ agent }: { agent: Agent }) => (
    <div
      onClick={() => setSelected(agent)}
      className="bg-card border border-border rounded-lg p-4 cursor-pointer hover:border-primary/30 transition-colors"
    >
      <div className="flex items-center gap-3 mb-2">
        <div className="w-8 h-8 rounded-lg bg-secondary flex items-center justify-center">
          <Bot className="h-4 w-4 text-muted-foreground" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <h4 className="text-sm font-medium text-foreground truncate">{agent.name}</h4>
            <StatusDot status={agent.status} />
          </div>
          <p className="text-[10px] text-muted-foreground truncate">{agent.role}</p>
        </div>
      </div>
      <p className="text-xs text-muted-foreground mb-2">{agent.currentTask}</p>
      <div className="flex items-center gap-1">
        <Clock className="h-2.5 w-2.5 text-muted-foreground" />
        <span className="text-[10px] text-muted-foreground">{agent.lastActive}</span>
      </div>
    </div>
  );

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-foreground">AI Team</h1>
        <p className="text-sm text-muted-foreground mt-1">Your AI workforce org chart and status</p>
      </div>

      {selected ? (
        <div className="bg-card border border-border rounded-lg p-6">
          <div className="flex items-start justify-between mb-6">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-xl bg-primary/20 flex items-center justify-center">
                <Bot className="h-6 w-6 text-primary" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h2 className="text-lg font-semibold text-foreground">{selected.name}</h2>
                  <StatusDot status={selected.status} />
                </div>
                <p className="text-xs text-muted-foreground">{selected.role}</p>
              </div>
            </div>
            <button onClick={() => setSelected(null)} className="p-1 hover:bg-accent rounded"><X className="h-4 w-4 text-muted-foreground" /></button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div>
              <h3 className="text-xs font-semibold text-muted-foreground uppercase mb-3">Responsibilities</h3>
              <ul className="space-y-1.5">
                {selected.responsibilities.map((r, i) => (
                  <li key={i} className="text-sm text-foreground/80 flex items-center gap-2">
                    <ChevronRight className="h-3 w-3 text-primary shrink-0" />{r}
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <h3 className="text-xs font-semibold text-muted-foreground uppercase mb-3">Recent Work</h3>
              <ul className="space-y-1.5">
                {selected.recentWork.map((r, i) => (
                  <li key={i} className="text-sm text-foreground/80">{r}</li>
                ))}
              </ul>
            </div>
            <div>
              <h3 className="text-xs font-semibold text-muted-foreground uppercase mb-3">Performance</h3>
              <div className="space-y-2">
                {selected.performance.map((p, i) => (
                  <div key={i} className="flex items-center justify-between">
                    <span className="text-xs text-muted-foreground">{p.label}</span>
                    <span className="text-sm font-semibold text-foreground">{p.value}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      ) : null}

      {/* Lead Agent */}
      <div>
        <h2 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider mb-3">Lead Agent</h2>
        <AgentCard agent={jeanette} />
      </div>

      {/* Sub-agent groups */}
      {subGroups.map(group => (
        <div key={group.label}>
          <h2 className="text-xs font-semibold text-muted-foreground uppercase tracking-wider mb-3">{group.label}</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {group.agents.map(agent => (
              <AgentCard key={agent.name} agent={agent} />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
};

export default AITeamPage;
