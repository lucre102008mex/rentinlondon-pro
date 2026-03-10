import { Shield, Key, RefreshCw, AlertCircle, Eye, EyeOff, Save, X } from "lucide-react";
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

const TokenManagementPage = () => {
    const [tokens, setTokens] = useState([
        { id: 1, name: "Supabase Anon Key", value: "eyJhbGciOiJIUzI...Ed8", env: "VITE_SUPABASE_PUBLISHABLE_KEY", status: "active", hidden: true },
        { id: 2, name: "Gemini Alex", value: "AIzaSyDtVQSO...euk", env: "GEMINI_API_KEY_ALEX", status: "active", hidden: true },
        { id: 3, name: "WhatsApp API", value: "EAAOZC9zP...ZA0", env: "WHATSAPP_TOKEN", status: "active", hidden: true },
    ]);

    const [isDialogOpen, setIsDialogOpen] = useState(false);
    const [selectedToken, setSelectedToken] = useState<any>(null);
    const [newValue, setNewValue] = useState("");

    const toggleVisibility = (id: number) => {
        setTokens(tokens.map(t =>
            t.id === id ? { ...t, hidden: !t.hidden } : t
        ));
    };

    const handleRotate = () => {
        if (!newValue.trim()) {
            toast.error("El nuevo valor no puede estar vacío");
            return;
        }

        setTokens(tokens.map(t =>
            t.id === selectedToken.id ? { ...t, value: newValue, hidden: true } : t
        ));

        toast.success(`Token "${selectedToken.name}" actualizado correctamente`);
        setIsDialogOpen(false);
        setNewValue("");
        setSelectedToken(null);
    };

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-2xl font-semibold text-foreground italic flex items-center gap-2">
                    <Shield className="text-primary" /> Token & Security Management
                </h1>
                <p className="text-sm text-muted-foreground mt-1">Manage API keys and security credentials across all services.</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                {tokens.map(token => (
                    <div key={token.id} className="bg-card border border-border rounded-xl p-5 space-y-4 hover:shadow-lg transition-all duration-300 group">
                        <div className="flex items-center justify-between">
                            <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center group-hover:bg-primary/20 transition-colors">
                                <Key className="text-primary h-5 w-5" />
                            </div>
                            <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${token.status === 'active' ? 'bg-status-active/20 text-status-active border border-status-active/30' : 'bg-destructive/20 text-destructive border border-destructive/30'
                                }`}>
                                {token.status}
                            </span>
                        </div>
                        <div>
                            <h3 className="text-sm font-semibold text-foreground">{token.name}</h3>
                            <p className="text-[10px] text-muted-foreground font-mono mt-1 opacity-70">{token.env}</p>
                        </div>
                        <div className="relative group/key">
                            <div className="bg-secondary/30 p-3 rounded-lg border border-border font-mono text-xs text-muted-foreground break-all min-h-[4rem] flex items-center pr-10">
                                {token.hidden ? "••••••••••••••••••••••••••••" : token.value}
                            </div>
                            <button
                                onClick={() => toggleVisibility(token.id)}
                                className="absolute right-2 top-1/2 -translate-y-1/2 p-2 hover:bg-primary/10 rounded-md transition-colors text-muted-foreground hover:text-primary"
                            >
                                {token.hidden ? <Eye className="h-4 w-4" /> : <EyeOff className="h-4 w-4" />}
                            </button>
                        </div>

                        <Dialog open={isDialogOpen && selectedToken?.id === token.id} onOpenChange={(open) => {
                            setIsDialogOpen(open);
                            if (!open) {
                                setSelectedToken(null);
                                setNewValue("");
                            }
                        }}>
                            <DialogTrigger asChild>
                                <Button
                                    variant="secondary"
                                    className="w-full text-xs gap-2 group-hover:bg-primary group-hover:text-primary-foreground transition-all"
                                    onClick={() => setSelectedToken(token)}
                                >
                                    <RefreshCw className="h-3 w-3" /> Rotate Key
                                </Button>
                            </DialogTrigger>
                            <DialogContent className="sm:max-w-md bg-card border-border">
                                <DialogHeader>
                                    <DialogTitle className="flex items-center gap-2">
                                        <RefreshCw className="h-5 w-5 text-primary" />
                                        Rotar {token.name}
                                    </DialogTitle>
                                    <DialogDescription className="text-xs">
                                        Introduce el nuevo valor para el token. Esta acción es irreversible en la interfaz.
                                    </DialogDescription>
                                </DialogHeader>
                                <div className="space-y-4 py-4">
                                    <div className="space-y-2">
                                        <Label htmlFor="token-value" className="text-xs px-1">Nuevo Valor del Token</Label>
                                        <Input
                                            id="token-value"
                                            placeholder="Pega aquí el nuevo API Key..."
                                            value={newValue}
                                            onChange={(e) => setNewValue(e.target.value)}
                                            className="font-mono text-xs bg-secondary/50"
                                        />
                                    </div>
                                    <div className="bg-amber-500/10 border border-amber-500/20 p-3 rounded flex items-start gap-2">
                                        <AlertCircle className="h-4 w-4 text-amber-500 shrink-0 mt-0.5" />
                                        <p className="text-[10px] text-amber-200/80 leading-relaxed">
                                            Recuerda que debes actualizar manualmente el archivo .env en el servidor de producción después de este cambio.
                                        </p>
                                    </div>
                                </div>
                                <DialogFooter className="flex sm:justify-between gap-2">
                                    <Button variant="ghost" onClick={() => setIsDialogOpen(false)} className="text-xs">
                                        <X className="h-3 w-3 mr-1" /> Cancelar
                                    </Button>
                                    <Button onClick={handleRotate} className="text-xs">
                                        <Save className="h-3 w-3 mr-1" /> Guardar Cambios
                                    </Button>
                                </DialogFooter>
                            </DialogContent>
                        </Dialog>
                    </div>
                ))}
            </div>

            <div className="bg-priority-urgent/10 border border-priority-urgent/20 p-5 rounded-xl flex items-start gap-4 backdrop-blur-sm">
                <div className="w-10 h-10 rounded-full bg-priority-urgent/20 flex items-center justify-center shrink-0">
                    <AlertCircle className="text-priority-urgent h-6 w-6" />
                </div>
                <div>
                    <h4 className="text-sm font-semibold text-priority-urgent uppercase tracking-wider">Aviso de Infraestructura</h4>
                    <p className="text-xs text-muted-foreground mt-1 leading-relaxed">
                        Cualquier rotación de keys requiere un reinicio del sistema **OpenClaw Gateway** en el clúster (AWS/Ubuntu).
                        Los cambios realizados aquí son para registro y visualización del panel administrativo.
                    </p>
                </div>
            </div>
        </div>
    );
};

export default TokenManagementPage;
