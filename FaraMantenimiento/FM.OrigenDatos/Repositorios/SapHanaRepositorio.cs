using FM.OrigenDatos.Modelos.Sap;
using Microsoft.Extensions.Configuration;
using Sap.Data.Hana;

namespace FM.OrigenDatos.Repositorios;

// Callers: SapServicio (ProgramacionServiceCollectionExtensions registra SapHanaRepositorio)
// API: BuscarArticulosAsync / BuscarProveedoresAsync — OITM / OCRD solo lectura
// Schema keys: ConnectionStrings:SapHana, Sap:Esquema; sin valor → FbConfigurado=false
// Confirm: no existe SapHanaRepositorio previo (Glob); patrón Fleet Data/SapHanaInventarioRepository
// User instruction: "Si la cadena no está configurada, la búsqueda debe responder... 'SAP no está configurado'"

// REGLA DEL NEGOCIO: en SAP solo se permiten consultas. Nada de INSERT/UPDATE/DELETE/CALL.
// Protecciones: (1) solo se ejecutan sentencias que empiezan con SELECT y sin ";" (EjecutarConsultaAsync);
// (2) cada consulta corre dentro de una transacción que SIEMPRE se revierte (nunca Commit);
// (3) el esquema solo acepta letras, números y "_" porque va escrito dentro del SQL.
// La protección definitiva es un usuario de HANA con permiso SELECT sobre OITM, OITW y OCRD únicamente.
public class SapHanaRepositorio
{
    private static readonly System.Text.RegularExpressions.Regex EsquemaValido =
        new("^[A-Za-z0-9_]{1,64}$", System.Text.RegularExpressions.RegexOptions.Compiled);

    private readonly string? _cs;
    private readonly string? _schema;

    public SapHanaRepositorio(IConfiguration config)
    {
        _cs = config.GetConnectionString("SapHana");
        var esquema = (config["Sap:Esquema"] ?? "").Trim();
        _schema = EsquemaValido.IsMatch(esquema) ? esquema : null;
    }

    public bool EstaConfigurado =>
        !string.IsNullOrWhiteSpace(_cs) && !string.IsNullOrWhiteSpace(_schema);

    public async Task<SapBusquedaResultado<SapArticuloModelo>> BuscarArticulosAsync(string? q, int take = 30, CancellationToken ct = default)
    {
        if (!EstaConfigurado)
            return NoConfigurado<SapArticuloModelo>();

        q = (q ?? "").Trim();
        if (q.Length < 2)
            return new SapBusquedaResultado<SapArticuloModelo> { FbConfigurado = true, Datos = Array.Empty<SapArticuloModelo>() };

        take = Math.Clamp(take, 1, 30);
        var like = "%" + q.Replace("%", "").Replace("_", "") + "%";
        var list = new List<SapArticuloModelo>();

        var sql = $"""
            SELECT TOP {take}
                T0."ItemCode",
                T0."ItemName",
                IFNULL(T0."InvntryUom", '') AS "Unidad",
                IFNULL(T0."AvgPrice", 0) AS "Costo",
                IFNULL((SELECT SUM(IFNULL(W."OnHand", 0)) FROM "{_schema}"."OITW" W WHERE W."ItemCode" = T0."ItemCode"), 0) AS "Existencia"
            FROM "{_schema}"."OITM" T0
            WHERE IFNULL(T0."frozenFor", 'N') = 'N'
              AND (
                UPPER(T0."ItemCode") LIKE UPPER(?)
                OR UPPER(T0."ItemName") LIKE UPPER(?)
              )
            ORDER BY T0."ItemCode"
            """;

        await EjecutarConsultaAsync(sql, new[] { like, like }, rd =>
        {
            list.Add(new SapArticuloModelo
            {
                FcCodigo = rd["ItemCode"]?.ToString() ?? "",
                FcNombre = rd["ItemName"]?.ToString() ?? "",
                FcUnidad = NullIfEmpty(rd["Unidad"]?.ToString()),
                FnCostoPromedio = ToDec(rd["Costo"]),
                FnExistencia = ToDec(rd["Existencia"])
            });
        }, ct);

        return new SapBusquedaResultado<SapArticuloModelo> { FbConfigurado = true, Datos = list };
    }

    public async Task<SapBusquedaResultado<SapProveedorModelo>> BuscarProveedoresAsync(string? q, int take = 30, CancellationToken ct = default)
    {
        if (!EstaConfigurado)
            return NoConfigurado<SapProveedorModelo>();

        q = (q ?? "").Trim();
        if (q.Length < 2)
            return new SapBusquedaResultado<SapProveedorModelo> { FbConfigurado = true, Datos = Array.Empty<SapProveedorModelo>() };

        take = Math.Clamp(take, 1, 30);
        var like = "%" + q.Replace("%", "").Replace("_", "") + "%";
        var list = new List<SapProveedorModelo>();

        var sql = $"""
            SELECT TOP {take}
                T0."CardCode",
                T0."CardName"
            FROM "{_schema}"."OCRD" T0
            WHERE T0."CardType" = 'S'
              AND IFNULL(T0."frozenFor", 'N') = 'N'
              AND (
                UPPER(T0."CardCode") LIKE UPPER(?)
                OR UPPER(T0."CardName") LIKE UPPER(?)
              )
            ORDER BY T0."CardName"
            """;

        await EjecutarConsultaAsync(sql, new[] { like, like }, rd =>
        {
            list.Add(new SapProveedorModelo
            {
                FcCodigo = rd["CardCode"]?.ToString() ?? "",
                FcNombre = rd["CardName"]?.ToString() ?? ""
            });
        }, ct);

        return new SapBusquedaResultado<SapProveedorModelo> { FbConfigurado = true, Datos = list };
    }

    /// <summary>
    /// Único punto que ejecuta SQL contra SAP. Solo acepta un SELECT (sin ";") y lo corre dentro de una
    /// transacción que se revierte al terminar: aunque alguien agregara una escritura, nunca se confirma.
    /// </summary>
    private async Task EjecutarConsultaAsync(string sql, IEnumerable<string> parametros,
        Action<System.Data.Common.DbDataReader> leerFila, CancellationToken ct)
    {
        var texto = sql.TrimStart();
        if (!texto.StartsWith("SELECT", StringComparison.OrdinalIgnoreCase) || texto.Contains(';'))
            throw new InvalidOperationException("En SAP solo se permiten consultas SELECT.");

        await using var cn = new HanaConnection(_cs);
        await cn.OpenAsync(ct);
        await using var tx = await cn.BeginTransactionAsync(ct);
        try
        {
            await using var cmd = cn.CreateCommand();
            cmd.Transaction = (HanaTransaction)tx;
            cmd.CommandText = texto;
            foreach (var p in parametros)
                AddText(cmd, p);

            await using var rd = await cmd.ExecuteReaderAsync(ct);
            while (await rd.ReadAsync(ct))
                leerFila(rd);
        }
        finally
        {
            await tx.RollbackAsync(CancellationToken.None); // nunca Commit
        }
    }

    private static SapBusquedaResultado<T> NoConfigurado<T>() => new()
    {
        FbConfigurado = false,
        FcMensaje = "SAP no está configurado",
        Datos = Array.Empty<T>()
    };

    private static void AddText(HanaCommand cmd, string value) =>
        cmd.Parameters.Add(new HanaParameter { HanaDbType = HanaDbType.NVarChar, Value = value });

    private static decimal ToDec(object? v)
    {
        if (v == null || v is DBNull) return 0;
        return Convert.ToDecimal(v);
    }

    private static string? NullIfEmpty(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}
