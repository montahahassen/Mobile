<?php
namespace App\Event\Listener;
use App\Entity\User;
use Doctrine\Persistence\Event\LifecycleEventArgs;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
class UserListener {
    public function __construct(
        private readonly UserPasswordHasherInterface $passwordEncoder)
        {}
    public function prePersist(LifecycleEventArgs $args)
    {
        $user=$args->getObject();
        if($user instanceof User )
            {
                //Hash the password
                $user->setPassword($this->passwordEncoder->hashPassword($user,$user->getPassword()));

            }
    }

    } 