import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import Layout from '../components/Layout';
import { useToast } from '@/hooks/use-toast';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { Search, Save, Package, CheckCircle2, XCircle, AlertCircle } from 'lucide-react';

const StokOpnameV2 = () => {
  const { profile } = useAuth();
  const { toast } = useToast();
  const [perangkat, setPerangkat] = useState([]);
  const [jenisPerangkatList, setJenisPerangkatList] = useState([]);
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [physicalCounts, setPhysicalCounts] = useState({});
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchMasterData();
    fetchPerangkat();
  }, []);

  const fetchMasterData = async () => {
    try {
      const { data, error } = await supabase
        .from('ms_jenis_perangkat')
        .select('*')
        .eq('is_active', true)
        .order('kode');

      if (error) throw error;
      setJenisPerangkatList(data || []);
    } catch (error) {
      console.error('Error fetching master data:', error);
      toast({
        variant: "destructive",
        title: "Error",
        description: "Gagal memuat data master: " + error.message,
      });
    }
  };

  const fetchPerangkat = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('perangkat')
        .select(`
          id,
          id_perangkat,
          nama_perangkat,
          jenis_perangkat_kode,
          jenis_barang_id,
          lokasi_kode,
          serial_number,
          merk,
          id_remoteaccess,
          spesifikasi_processor,
          kapasitas_ram,
          mac_ethernet,
          mac_wireless,
          ip_ethernet,
          ip_wireless,
          serial_number_monitor,
          tanggal_entry,
          status_perangkat,
          petugas_id,
          jenis_perangkat:ms_jenis_perangkat!perangkat_jenis_perangkat_kode_fkey(kode, nama),
          jenis_barang:ms_jenis_barang!perangkat_jenis_barang_id_fkey(id, nama),
          lokasi:ms_lokasi!perangkat_lokasi_kode_fkey(kode, nama),
          petugas:profiles!perangkat_petugas_id_fkey(id, full_name),
          perangkat_storage(id, jenis_storage, kapasitas)
        `)
        .limit(1000);

      if (error) throw error;
      setPerangkat(data || []);
    } catch (error) {
      console.error('Error fetching perangkat:', error);
      toast({
        variant: "destructive",
        title: "Error",
        description: "Gagal memuat data perangkat: " + error.message,
      });
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString) => {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleDateString('id-ID', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const handlePhysicalCountChange = (perangkatId, value) => {
    setPhysicalCounts((prev) => ({
      ...prev,
      [perangkatId]: value,
    }));
  };

  const handleSave = async () => {
    try {
      setSaving(true);
      
      const updates = Object.entries(physicalCounts)
        .filter(([_, count]) => count && count !== '')
        .map(([perangkatId, count]) => ({
          id: perangkatId,
          count: parseInt(count) || 0,
        }));

      if (updates.length === 0) {
        toast({
          variant: "destructive",
          title: "Error",
          description: "Tidak ada data yang akan disimpan",
        });
        return;
      }

      let successCount = 0;
      for (const update of updates) {
        try {
          const { error } = await supabase
            .from('perangkat')
            .update({
              updated_at: new Date().toISOString(),
            })
            .eq('id', update.id);

          if (error) {
            console.warn(`Could not update perangkat ${update.id}:`, error.message);
          } else {
            successCount++;
          }
        } catch (err) {
          console.error(`Error updating perangkat ${update.id}:`, err);
        }
      }

      if (successCount > 0) {
        toast({
          variant: "success",
          title: "Success",
          description: `Berhasil menyimpan ${successCount} dari ${updates.length} data perangkat`,
        });
        setPhysicalCounts({});
        await fetchPerangkat();
      } else {
        toast({
          variant: "destructive",
          title: "Error",
          description: "Gagal menyimpan data. Pastikan kolom physical_count ada di tabel perangkat.",
        });
      }
    } catch (error) {
      console.error('Error saving:', error);
      toast({
        variant: "destructive",
        title: "Error",
        description: "Gagal menyimpan data: " + error.message,
      });
    } finally {
      setSaving(false);
    }
  };

  const filteredPerangkat = perangkat.filter((item) => {
    const matchesSearch = 
      !searchTerm ||
      item.id_perangkat?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.nama_perangkat?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.serial_number?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.jenis_perangkat?.nama?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.jenis_barang?.nama?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.lokasi?.nama?.toLowerCase().includes(searchTerm.toLowerCase());

    const matchesCategory = 
      categoryFilter === 'all' || 
      item.jenis_perangkat_kode === categoryFilter;

    return matchesSearch && matchesCategory;
  });

  // Calculate stats
  const totalPerangkat = perangkat.length;
  const layakCount = perangkat.filter(p => p.status_perangkat === 'layak').length;
  const rusakCount = perangkat.filter(p => p.status_perangkat === 'rusak').length;
  const pendingCount = Object.keys(physicalCounts).length;

  return (
    <Layout>
      <div className="min-h-screen bg-background p-8">
        <div className="max-w-7xl mx-auto space-y-8">
          {/* Header */}
          <div className="space-y-2">
            <h1 className="text-4xl font-bold text-foreground tracking-tight">Stock Opname</h1>
            <p className="text-muted-foreground text-lg">
              Kelola dan update data inventaris perangkat IT
            </p>
          </div>

          {/* Stats Cards */}
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Total Perangkat</CardTitle>
                <Package className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{totalPerangkat}</div>
                <p className="text-xs text-muted-foreground mt-1">
                  Semua perangkat terdaftar
                </p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Layak</CardTitle>
                <CheckCircle2 className="h-4 w-4 text-green-500" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-green-500">{layakCount}</div>
                <p className="text-xs text-muted-foreground mt-1">
                  Perangkat dalam kondisi baik
                </p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Rusak</CardTitle>
                <XCircle className="h-4 w-4 text-red-500" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-red-500">{rusakCount}</div>
                <p className="text-xs text-muted-foreground mt-1">
                  Perangkat perlu perbaikan
                </p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Pending Update</CardTitle>
                <AlertCircle className="h-4 w-4 text-yellow-500" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold text-yellow-500">{pendingCount}</div>
                <p className="text-xs text-muted-foreground mt-1">
                  Menunggu penyimpanan
                </p>
              </CardContent>
            </Card>
          </div>

          {/* Search and Filter */}
          <Card>
            <CardContent className="pt-6">
              <div className="flex flex-col sm:flex-row gap-4">
                <div className="relative flex-1">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    type="text"
                    placeholder="Cari perangkat, serial number, jenis, lokasi..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10"
                  />
                </div>
                <Select value={categoryFilter} onValueChange={setCategoryFilter}>
                  <SelectTrigger className="w-full sm:w-[200px]">
                    <SelectValue placeholder="Filter Kategori" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">Semua Kategori</SelectItem>
                    {jenisPerangkatList.map((jenis) => (
                      <SelectItem key={jenis.id} value={jenis.kode}>
                        {jenis.kode} - {jenis.nama}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {Object.keys(physicalCounts).length > 0 && (
                  <Button
                    onClick={handleSave}
                    disabled={saving}
                    className="w-full sm:w-auto"
                  >
                    <Save className="h-4 w-4 mr-2" />
                    {saving ? 'Menyimpan...' : `Simpan (${Object.keys(physicalCounts).length})`}
                  </Button>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Table */}
          <Card>
            <CardHeader>
              <CardTitle>Daftar Perangkat</CardTitle>
              <CardDescription>
                {filteredPerangkat.length} dari {perangkat.length} perangkat
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="rounded-md border">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead className="text-center">ID Perangkat</TableHead>
                      <TableHead className="text-center">Nama Perangkat</TableHead>
                      <TableHead className="text-center">ID Remote Access</TableHead>
                      <TableHead className="text-center">Tanggal Entry</TableHead>
                      <TableHead className="text-center">Petugas</TableHead>
                      <TableHead className="text-center">Jenis Perangkat</TableHead>
                      <TableHead className="text-center">Jenis Barang</TableHead>
                      <TableHead className="text-center">Lokasi</TableHead>
                      <TableHead className="text-center">Status</TableHead>
                      <TableHead className="text-center">Physical Count</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {loading ? (
                      <TableRow>
                        <TableCell colSpan={10} className="text-center py-12">
                          <div className="flex flex-col items-center justify-center gap-3">
                            <div className="animate-spin rounded-full h-8 w-8 border-2 border-primary border-t-transparent"></div>
                            <span className="text-sm text-muted-foreground">Memuat data...</span>
                          </div>
                        </TableCell>
                      </TableRow>
                    ) : filteredPerangkat.length === 0 ? (
                      <TableRow>
                        <TableCell colSpan={10} className="text-center py-12 text-muted-foreground">
                          Tidak ada data ditemukan
                        </TableCell>
                      </TableRow>
                    ) : (
                      filteredPerangkat.map((item) => (
                        <TableRow key={item.id} className="hover:bg-muted/50 transition-colors">
                          <TableCell className="text-center font-mono text-sm font-medium">
                            {item.id_perangkat}
                          </TableCell>
                          <TableCell className="text-center">{item.nama_perangkat}</TableCell>
                          <TableCell className="text-center text-muted-foreground">
                            {item.id_remoteaccess || '-'}
                          </TableCell>
                          <TableCell className="text-center text-sm text-muted-foreground">
                            {formatDate(item.tanggal_entry)}
                          </TableCell>
                          <TableCell className="text-center">{item.petugas?.full_name || '-'}</TableCell>
                          <TableCell className="text-center">{item.jenis_perangkat?.nama || '-'}</TableCell>
                          <TableCell className="text-center">{item.jenis_barang?.nama || '-'}</TableCell>
                          <TableCell className="text-center">{item.lokasi?.nama || item.lokasi?.kode || '-'}</TableCell>
                          <TableCell className="text-center">
                            <Badge
                              variant={
                                item.status_perangkat === 'layak'
                                  ? 'default'
                                  : 'destructive'
                              }
                              className={
                                item.status_perangkat === 'layak'
                                  ? 'bg-green-500/10 text-green-500 hover:bg-green-500/20 border-green-500/20'
                                  : 'bg-red-500/10 text-red-500 hover:bg-red-500/20 border-red-500/20'
                              }
                            >
                              {(() => {
                                if (item.status_perangkat === 'layak') return 'Layak';
                                if (item.status_perangkat === 'rusak') return 'Rusak';
                                return item.status_perangkat || '-';
                              })()}
                            </Badge>
                          </TableCell>
                          <TableCell className="text-center">
                            <Input
                              type="number"
                              min="0"
                              value={physicalCounts[item.id] || ''}
                              onChange={(e) =>
                                handlePhysicalCountChange(item.id, e.target.value)
                              }
                              className="w-24 mx-auto text-center"
                              placeholder="0"
                            />
                          </TableCell>
                        </TableRow>
                      ))
                    )}
                  </TableBody>
                </Table>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </Layout>
  );
};

export default StokOpnameV2;
