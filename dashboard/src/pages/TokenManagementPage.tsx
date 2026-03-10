import { Shield, Key, Eye, EyeOff, Save, X, AlertCircle, ChevronDown, ChevronUp } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

interface ApiKeySlot {
    provider: "Gemini" | "Anthropic" | "OpenAI";
    value: string;
    hidden: boolean;
    status: "active" | "empty";
}

interface AgentProfile {
    name: string;
    role: string;
    color: string;
    keys: ApiKeySlot[];
    expanded: boolean;
}

const providerColors: Record<string, string> = {
    Gemini: "text-blue-400",
    Anthropic: "text-orange-400",
    OpenAI: "text-green-400",
};

const providerBg: Record<string, string> = {
    Gemini: "bg-blue-500/10 border-blue-500/20",
    Anthropic: "bg-orange-500/10 border-orange-500/20",
    OpenAI: "bg-green-500/10 border-green-500/20",
};

const buildSlots = (gemini: string, anthropic: string, openai: string): ApiKeySlot[] => [
    { provider: "Gemini", value: gemini, hidden: true, status: gemini ? "active" : "empty" },
    { provider: "Anthropic", value: anthropic, hidden: true, status: anthropic ? "active" : "empty" },
    { provider: "OpenAI", value: openai, hidden: true, status: openai ? "active" : "empty" },
];

const initialAgents: AgentProfile[] = [
    { name: "Alex", role: "Admin / Sistema", color: "bg-purple-500/20 text-purple-300", keys: buildSlots("AIzaSyDtVQ...Alex", "", ""), expanded: true },
    { name: "Ivy", role: "Captación General", color: "bg-primary/20 text-primary", keys: buildSlots("AIzaSy...Ivy", "sk-ant-...Ivy", ""), expanded: false },
    { name: "Salo", role: "Gumtree & Listings", color: "bg-cyan-500/20 text-cyan-300", keys: buildSlots("AIzaSy...Salo", "", ""), expanded: false },
    { name: "Rose", role: "Ads Performance", color: "bg-rose-500/20 text-rose-300", keys: buildSlots("AIzaSy...Rose", "sk-ant-...Rose", ""), expanded: false },
    { name: "Jeanette", role: "Internacional / Visas", color: "bg-amber-500/20 text-amber-300", keys: buildSlots("", "", "sk-...Jean"), expanded: false },
];

const globalInfraKeys = [
    { name: "Supabase Anon Key", env: "VITE_SUPABASE_PUBLISHABLE_KEY", value: "eyJhbGciOiJIUzI...Ed8" },
    { name: "WhatsApp API Token", env: "WHATSAPP_TOKEN", value: "EAAOZC9zP...ZA0" },
];

const TokenManagementPage = () => {
    const [agents, setAgents] = useState(initialAgents);
    const [editTarget, setEditTarget] = useState<{ agentIndex: number; slotIndex: number } | null>(null);
    const [newValue, setNewValue] = useState("");
    const [globalHidden, setGlobalHidden] = useState<boolean[]>(globalInfraKeys.map(() => true));

    const toggleGlobalKey = (i: number) => setGlobalHidden(prev => prev.map((h, idx) => idx === i ? !h : h));

    const toggleExpand = (idx: number) => {
        setAgents(prev => prev.map((a, i) => i === idx ? { ...a, expanded: !a.expanded } : a));
    };

    const toggleVisibility = (agentIdx: number, slotIdx: number) => {
        setAgents(prev => prev.map((a, ai) =>
            ai !== agentIdx ? a : {
                ...a,
                keys: a.keys.map((k, ki) => ki === slotIdx ? { ...k, hidden: !k.hidden } : k)
            }
        ));
    };

    const handleSave = () => {
        if (!editTarget) return;
        if (!newValue.trim()) {
            toast.error("El valor no puede estar vacío");
            return;
        }
        const { agentIndex, slotIndex } = editTarget;
        setAgents(prev => prev.map((a, ai) =>
            ai !== agentIndex ? a : {
                ...a,
                keys: a.keys.map((k, ki) => ki !== slotIndex ? k : { ...k, value: newValue, hidden: true, status: "active" })
            }
        ));
        toast.success(`API Key de ${agents[agentIndex].keys[slotIndex].provider} para ${agents[agentIndex].name} actualizada`);
        setEditTarget(null);
        setNewValue("");
    };

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-2xl font-semibold text-foreground italic flex items-center gap-2">
                    <Shield className="text-primary" /> Token & Security Management
                </h1>
                <p className="text-sm text-muted-foreground mt-1">API Keys por agente — Gemini · Anthropic · OpenAI</p>
            </div>

            {/* Global Infra Keys */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {globalInfraKeys.map((key, i) => (
                    <div key={i} className="bg-card border border-border rounded-xl p-4 flex items-center justify-between gap-4">
                        <div>
                            <div className="flex items-center gap-2 mb-1">
                                <Key className="h-3.5 w-3.5 text-muted-foreground" />
                                <span className="text-sm font-medium text-foreground">{key.name}</span>
                                <span className="text-[10px] bg-status-active/20 text-status-active border border-status-active/30 px-1.5 py-0.5 rounded-full font-bold uppercase">active</span>
                            </div>
                            <p className="text-[10px] font-mono text-muted-foreground opacity-60">{key.env}</p>
                            <p className="text-xs font-mono text-muted-foreground mt-1">{globalHidden[i] ? "••••••••••••••••••••••" : key.value}</p>
                        </div>
                        <button onClick={() => toggleGlobalKey(i)} className="p-2 hover:bg-primary/10 rounded-md text-muted-foreground hover:text-primary transition-colors shrink-0">
                            {globalHidden[i] ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4" />}
                        </button>
                    </div>
                ))}
            </div>

            {/* Per-Agent API Keys */}
            <div className="space-y-3">
                {agents.map((agent, agentIdx) => (
                    <div key={agent.name} className="bg-card border border-border rounded-xl overflow-hidden">
                        {/* Agent Header */}
                        <button
                            onClick={() => toggleExpand(agentIdx)}
                            className="w-full px-5 py-4 flex items-center justify-between hover:bg-accent/40 transition-colors"
                        >
                            <div className="flex items-center gap-3">
                                <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold ${agent.color}`}>
                                    {agent.name[0]}
                                </div>
                                <div className="text-left">
                                    <p className="text-sm font-semibold text-foreground">{agent.name}</p>
                                    <p className="text-[10px] text-muted-foreground">{agent.role}</p>
                                </div>
                                <div className="flex items-center gap-1.5 ml-2">
                                    {agent.keys.map((k) => (
                                        <span
                                            key={k.provider}
                                            className={`text-[9px] font-bold px-1.5 py-0.5 rounded border ${k.status === "active"
                                                ? "bg-status-active/15 text-status-active border-status-active/30"
                                                : "bg-muted/20 text-muted-foreground border-border"
                                                }`}
                                        >
                                            {k.provider}
                                        </span>
                                    ))}
                                </div>
                            </div>
                            {agent.expanded ? <ChevronUp className="h-4 w-4 text-muted-foreground" /> : <ChevronDown className="h-4 w-4 text-muted-foreground" />}
                        </button>

                        {/* Key Slots */}
                        {agent.expanded && (
                            <div className="px-5 pb-5 grid grid-cols-1 md:grid-cols-3 gap-3">
                                {agent.keys.map((slot, slotIdx) => (
                                    <div key={slot.provider} className={`rounded-lg border p-3 space-y-2 ${providerBg[slot.provider]}`}>
                                        <div className="flex items-center justify-between">
                                            <span className={`text-xs font-bold ${providerColors[slot.provider]}`}>{slot.provider}</span>
                                            <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded-full border ${slot.status === "active"
                                                ? "bg-status-active/15 text-status-active border-status-active/30"
                                                : "bg-muted/20 text-muted-foreground border-border"
                                                }`}>
                                                {slot.status}
                                            </span>
                                        </div>
                                        <div className="relative">
                                            <div className="bg-secondary/40 px-3 py-2 rounded font-mono text-[10px] text-muted-foreground break-all min-h-[36px] flex items-center pr-8">
                                                {slot.status === "empty" ? (
                                                    <span className="italic opacity-50">No configurada</span>
                                                ) : (
                                                    slot.hidden ? "••••••••••••••••••" : slot.value
                                                )}
                                            </div>
                                            {slot.status === "active" && (
                                                <button
                                                    onClick={() => toggleVisibility(agentIdx, slotIdx)}
                                                    className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-primary transition-colors"
                                                >
                                                    {slot.hidden ? <Eye className="h-3.5 w-3.5" /> : <EyeOff className="h-3.5 w-3.5" />}
                                                </button>
                                            )}
                                        </div>

                                        <Dialog
                                            open={editTarget?.agentIndex === agentIdx && editTarget?.slotIndex === slotIdx}
                                            onOpenChange={(open) => {
                                                if (!open) { setEditTarget(null); setNewValue(""); }
                                            }}
                                        >
                                            <DialogTrigger asChild>
                                                <Button
                                                    variant="secondary"
                                                    size="sm"
                                                    className="w-full text-[10px] h-7"
                                                    onClick={() => setEditTarget({ agentIndex: agentIdx, slotIndex: slotIdx })}
                                                >
                                                    {slot.status === "empty" ? "＋ Añadir Key" : "↺ Rotar Key"}
                                                </Button>
                                            </DialogTrigger>
                                            <DialogContent className="sm:max-w-md bg-card border-border">
                                                <DialogHeader>
                                                    <DialogTitle className="flex items-center gap-2 text-sm">
                                                        <Key className="h-4 w-4 text-primary" />
                                                        {agent.name} — {slot.provider} API Key
                                                    </DialogTitle>
                                                    <DialogDescription className="text-xs">
                                                        Introduce el nuevo valor para la clave. Esta acción es irreversible en la interfaz.
                                                    </DialogDescription>
                                                </DialogHeader>
                                                <div className="space-y-4 py-3">
                                                    <div className="space-y-2">
                                                        <Label htmlFor="key-value" className="text-xs px-1">Nuevo API Key</Label>
                                                        <Input
                                                            id="key-value"
                                                            placeholder={`Pega aquí el API Key de ${slot.provider}...`}
                                                            value={newValue}
                                                            onChange={(e) => setNewValue(e.target.value)}
                                                            className="font-mono text-xs bg-secondary/50"
                                                        />
                                                    </div>
                                                    <div className="bg-amber-500/10 border border-amber-500/20 p-3 rounded flex items-start gap-2">
                                                        <AlertCircle className="h-4 w-4 text-amber-500 shrink-0 mt-0.5" />
                                                        <p className="text-[10px] text-amber-200/80 leading-relaxed">
                                                            Recuerda actualizar también el archivo <code>.env</code> y el <code>config.yaml</code> de OpenClaw en el servidor de producción.
                                                        </p>
                                                    </div>
                                                </div>
                                                <DialogFooter className="flex sm:justify-between gap-2">
                                                    <Button variant="ghost" size="sm" onClick={() => { setEditTarget(null); setNewValue(""); }} className="text-xs">
                                                        <X className="h-3 w-3 mr-1" /> Cancelar
                                                    </Button>
                                                    <Button size="sm" onClick={handleSave} className="text-xs">
                                                        <Save className="h-3 w-3 mr-1" /> Guardar
                                                    </Button>
                                                </DialogFooter>
                                            </DialogContent>
                                        </Dialog>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                ))}
            </div>

            {/* Infra Warning */}
            <div className="bg-priority-urgent/10 border border-priority-urgent/20 p-5 rounded-xl flex items-start gap-4 backdrop-blur-sm">
                <div className="w-10 h-10 rounded-full bg-priority-urgent/20 flex items-center justify-center shrink-0">
                    <AlertCircle className="text-priority-urgent h-6 w-6" />
                </div>
                <div>
                    <h4 className="text-sm font-semibold text-priority-urgent uppercase tracking-wider">Aviso de Infraestructura</h4>
                    <p className="text-xs text-muted-foreground mt-1 leading-relaxed">
                        Cualquier rotación de keys requiere un reinicio del sistema <strong>OpenClaw Gateway</strong> en el clúster (AWS/Ubuntu).
                        Los cambios realizados aquí son para registro y visualización del panel administrativo — no se propagan automáticamente al servidor.
                    </p>
                </div>
            </div>
        </div>
    );
};

export default TokenManagementPage;
