import { useState } from "react";
import { Search, Filter, FileText, Calendar, Tag, X } from "lucide-react";

interface MemoryDoc {
  id: string;
  title: string;
  category: string;
  created: string;
  preview: string;
  content: string;
}

const categories = [
  'All',
  'Tenant Scripts & AI Prompts',
  'Property Listings & Descriptions',
  'Automation SOPs & Workflows',
  'Landlord & Supplier Notes',
  'Archive',
];

const docs: MemoryDoc[] = [
  { id: '1', title: 'WhatsApp Lead Qualification Script', category: 'Tenant Scripts & AI Prompts', created: 'Mar 5, 2026', preview: 'Automated greeting and qualification flow for WhatsApp Business leads...', content: 'Full script with branching logic for tenant qualification via WhatsApp. Covers: income verification, move-in date, references, guarantor requirements...' },
  { id: '2', title: 'Gumtree Listing Template — 2-Bed', category: 'Property Listings & Descriptions', created: 'Mar 3, 2026', preview: 'Standard template for 2-bedroom flats listing on Gumtree with SEO...', content: 'Template includes: headline formula, key features section, transport links, pricing structure, professional photo guidelines...' },
  { id: '3', title: 'Jeanette Escalation SOP', category: 'Automation SOPs & Workflows', created: 'Feb 28, 2026', preview: 'Standard operating procedure for when Jeanette escalates to human...', content: 'Escalation triggers: unrecognized intent, payment discussions, complaints, maintenance requests over £500. Response time: 15 minutes during business hours...' },
  { id: '4', title: 'Landlord Onboarding Checklist', category: 'Landlord & Supplier Notes', created: 'Feb 25, 2026', preview: 'Step-by-step onboarding process for new landlord partners...', content: 'Checklist: property inspection, contract signing, key handover, photo session, listing creation, pricing analysis, tenant matching setup...' },
  { id: '5', title: 'Facebook Marketplace Bot Config', category: 'Automation SOPs & Workflows', created: 'Feb 20, 2026', preview: 'Configuration guide for the Facebook Marketplace auto-responder...', content: 'Bot configuration: response templates, qualification questions, viewing scheduling, follow-up sequences. Rate limits and compliance notes...' },
  { id: '6', title: 'Competitor Pricing Analysis — Zone 2', category: 'Archive', created: 'Feb 15, 2026', preview: 'Market research on rental pricing across Zone 2 postcodes...', content: 'Detailed breakdown of average rents by bedroom count across E15, E20, SE1, SW9, N1. Comparison with our listings and margin analysis...' },
];

const MemoryPage = () => {
  const [search, setSearch] = useState('');
  const [catFilter, setCatFilter] = useState('All');
  const [selected, setSelected] = useState<MemoryDoc | null>(null);

  const filtered = docs.filter(d => {
    const matchesSearch = d.title.toLowerCase().includes(search.toLowerCase()) || d.preview.toLowerCase().includes(search.toLowerCase());
    const matchesCat = catFilter === 'All' || d.category === catFilter;
    return matchesSearch && matchesCat;
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-foreground">Memory</h1>
        <p className="text-sm text-muted-foreground mt-1">Searchable knowledge base and document library</p>
      </div>

      <div className="flex gap-3">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search documents..."
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

      {selected ? (
        <div className="bg-card border border-border rounded-lg p-6">
          <div className="flex items-start justify-between mb-4">
            <div>
              <h2 className="text-lg font-semibold text-foreground">{selected.title}</h2>
              <div className="flex items-center gap-3 mt-2">
                <span className="text-[10px] text-muted-foreground flex items-center gap-1"><Calendar className="h-3 w-3" /> {selected.created}</span>
                <span className="text-[10px] bg-secondary text-secondary-foreground px-2 py-0.5 rounded">{selected.category}</span>
              </div>
            </div>
            <button onClick={() => setSelected(null)} className="p-1 hover:bg-accent rounded"><X className="h-4 w-4 text-muted-foreground" /></button>
          </div>
          <p className="text-sm text-foreground/80 leading-relaxed">{selected.content}</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map(doc => (
            <div
              key={doc.id}
              onClick={() => setSelected(doc)}
              className="bg-card border border-border rounded-lg p-4 cursor-pointer hover:border-primary/30 transition-colors"
            >
              <div className="flex items-start gap-3 mb-3">
                <FileText className="h-4 w-4 text-primary shrink-0 mt-0.5" />
                <h3 className="text-sm font-medium text-foreground leading-tight">{doc.title}</h3>
              </div>
              <p className="text-xs text-muted-foreground mb-3 line-clamp-2">{doc.preview}</p>
              <div className="flex items-center gap-2">
                <span className="text-[10px] text-muted-foreground flex items-center gap-1"><Calendar className="h-2.5 w-2.5" />{doc.created}</span>
                <span className="text-[10px] bg-secondary text-secondary-foreground px-1.5 py-0.5 rounded">{doc.category}</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default MemoryPage;
