using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.HttpsPolicy;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.EntityFrameworkCore;
using WebSample.Models;
using NETCoreSyncServer;

namespace WebSample
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        public void ConfigureServices(IServiceCollection services)
        {
            services.AddDbContext<DatabaseContext>(options =>
            {
                String host = "localhost";
                if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("NETCORESYNCSERVER_POSTGRES_HOST")))
                {
                    host = Environment.GetEnvironmentVariable("NETCORESYNCSERVER_POSTGRES_HOST")!;
                }
                options.UseNpgsql($"Host={host};Database=NETCoreSyncServerTimeStampDB;Username=NETCoreSyncServerTimeStamp_User;Password=NETCoreSyncServerTimeStamp_Password");
            });

            services.AddControllersWithViews();

            // We can pass arguments to dotnet run (or dotnet myprogram.dll) like:
            // If using "dotnet run" project root directory: dotnet run -- minimumSchemaVersion=100
            // If executing dll: dotnet myprogram.dll minimumSchemaVersion=100
            // If argument is not passed, then the default value will be used (int will be zero)
            var testMinimumSchemaVersion = Configuration.GetValue<int>("minimumSchemaVersion");
            SyncEvent syncEvent = new SyncEvent();
            syncEvent.OnHandshake = (request) => 
            {
                // This is a chance to force your users to upgrade their app first before continuing the sync process.
                // App features shall evolve over time, along with its database, so the schema may also be changed.
                // Server's database will always likely to represent the latest version, so forcing users to upgrade first
                // seems the correct move to do. User upgrades (using Moor's Migration techniques) should bring existing
                // databases to the latest changes, therefore it will be safe to continue the sync with the server's database.
                // NOTE: Scenarios for supporting backward-compatibility (support older database schemas) seems too complicated,
                // and will likely require NETCoreSyncServer component to do complex work + deeper integration, so this is not
                // supported (for now).
                // The following example shows what Moor's schemaVersion that is supported by the server's database.
                if (request.SchemaVersion <= testMinimumSchemaVersion)
                {
                    return "Please update your application first before performing synchronization";
                }
                return null;
            };
            // Your subclass of SyncEngine's service lifetime is supposed to follow your AddDbContext's lifetime, therefore
            // whenever SyncEngine is instantiated by the middleware, it will always have the same lifetime as the database.
            // The following SyncEngine's subclass uses AddScoped(), because AddDbContext by default also uses AddScoped(),
            // And the serviceType registered as SyncEngine, while the implementation uses the subclass (CustomSyncEngine) type. 
            services.AddScoped<SyncEngine, CustomSyncEngine>();
            services.AddNETCoreSyncServer(syncEvent: syncEvent);
        }

        public void Configure(IApplicationBuilder app, IWebHostEnvironment env, DatabaseContext databaseContext)
        {
            // Helper arguments to clear database for testing
            var testClearDatabase = Configuration.GetValue<bool>("clearDatabase");
            if (testClearDatabase)
            {
                databaseContext.Persons.RemoveRange(databaseContext.Persons);
                databaseContext.Areas.RemoveRange(databaseContext.Areas);
                databaseContext.CustomObjects.RemoveRange(databaseContext.CustomObjects);
                databaseContext.SaveChanges();
            }

            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }
            else
            {
                app.UseExceptionHandler("/Home/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
            }
            app.UseHttpsRedirection();
            app.UseStaticFiles();

            app.UseRouting();

            app.UseAuthorization();

            app.UseNETCoreSyncServer();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllerRoute(
                    name: "default",
                    pattern: "{controller=Home}/{action=Index}/{id?}");
            });
        }
    }
}
