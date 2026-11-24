<?php
namespace App\Controller;

use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

class HomeController
{
    #[Route('/', name: 'home')]
    public function index(): Response
    {
        return new Response('<h1>Bienvenue sur GreenHouse 🌱</h1><p>Symfony fonctionne !</p>');
    }
}