import { useState } from "react";
import { Search, User, Mail, MessageCircle, Phone } from "lucide-react";

interface Contact {
  id: string;
  name: string;
  role: string;
  handle: string;
  handleType: 'WhatsApp' | 'Email' | 'Telegram';
  timezone: string;
  category: string;
  notes: string;
  compensation?: string;
}

const categories = ['All', 'Internal Team', 'Content Team', 'External', 'Clients'];

const contacts: Contact[] = [
  { id: '1', name: 'Maria Santos', role: 'Virtual Assistant', handle: '+44 7xxx xxx001', handleType: 'WhatsApp', timezone: 'GMT+0', category: 'Internal Team', notes: 'Handles admin tasks, available 9-5 weekdays', compensation: '£15/hr' },
  { id: '2', name: 'Dev Kumar', role: 'Tech Support', handle: 'dev@email.com', handleType: 'Email', timezone: 'GMT+5:30', category: 'Internal Team', notes: 'AWS & Supabase specialist, responds within 2h', compensation: '£25/hr' },
  { id: '3', name: 'Alex Chen', role: 'Video Editor', handle: '@alexchen', handleType: 'Telegram', timezone: 'GMT+8', category: 'Content Team', notes: 'YouTube & TikTok editing, 48h turnaround', compensation: '£50/video' },
  { id: '4', name: 'Sarah Williams', role: 'Thumbnail Designer', handle: 'sarah@email.com', handleType: 'Email', timezone: 'GMT+0', category: 'Content Team', notes: 'Creates YouTube thumbnails, Canva expert', compensation: '£15/thumb' },
  { id: '5', name: 'James Mitchell', role: 'Landlord — Shoreditch', handle: '+44 7xxx xxx005', handleType: 'WhatsApp', timezone: 'GMT+0', category: 'External', notes: '3 properties, prefers WhatsApp, responsive' },
  { id: '6', name: 'Priya Patel', role: 'Landlord — Stratford', handle: '+44 7xxx xxx006', handleType: 'WhatsApp', timezone: 'GMT+0', category: 'External', notes: '2 properties, monthly check-in preferred' },
  { id: '7', name: 'Tom Baker', role: 'Lead — 2-Bed Canary Wharf', handle: '+44 7xxx xxx007', handleType: 'WhatsApp', timezone: 'GMT+0', category: 'Clients', notes: 'Budget £1800/mo, move-in April, references verified' },
  { id: '8', name: 'Emma Johnson', role: 'Lead — Studio Brixton', handle: 'emma@email.com', handleType: 'Email', timezone: 'GMT+0', category: 'Clients', notes: 'Budget £1200/mo, professional, needs pet-friendly' },
];

const handleIcons = { WhatsApp: MessageCircle, Email: Mail, Telegram: Phone };

const ContactsPage = () => {
  const [search, setSearch] = useState('');
  const [catFilter, setCatFilter] = useState('All');

  const filtered = contacts.filter(c => {
    const matchesSearch = c.name.toLowerCase().includes(search.toLowerCase()) || c.role.toLowerCase().includes(search.toLowerCase());
    const matchesCat = catFilter === 'All' || c.category === catFilter;
    return matchesSearch && matchesCat;
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-foreground">Contacts</h1>
        <p className="text-sm text-muted-foreground mt-1">CRM for your team, partners, and clients</p>
      </div>

      <div className="flex gap-3">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search contacts..."
            className="w-full bg-secondary border border-border rounded-lg pl-9 pr-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-primary"
          />
        </div>
        <select
          value={catFilter}
          onChange={(e) => setCatFilter(e.target.value)}
          className="bg-secondary text-secondary-foreground text-xs rounded-lg px-3 py-2 border border-border"
        >
          {categories.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filtered.map(contact => {
          const Icon = handleIcons[contact.handleType];
          return (
            <div key={contact.id} className="bg-card border border-border rounded-lg p-4 hover:border-primary/30 transition-colors">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 rounded-full bg-secondary flex items-center justify-center">
                  <User className="h-4 w-4 text-muted-foreground" />
                </div>
                <div>
                  <h3 className="text-sm font-medium text-foreground">{contact.name}</h3>
                  <p className="text-[10px] text-muted-foreground">{contact.role}</p>
                </div>
              </div>
              <div className="space-y-2 mb-3">
                <div className="flex items-center gap-2">
                  <Icon className="h-3 w-3 text-muted-foreground" />
                  <span className="text-xs text-foreground/80">{contact.handle}</span>
                </div>
                <p className="text-[10px] text-muted-foreground">🕐 {contact.timezone}</p>
                {contact.compensation && <p className="text-[10px] text-primary">💰 {contact.compensation}</p>}
              </div>
              <p className="text-xs text-muted-foreground">{contact.notes}</p>
              <div className="mt-3">
                <span className="text-[10px] bg-secondary text-secondary-foreground px-2 py-0.5 rounded">{contact.category}</span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default ContactsPage;
